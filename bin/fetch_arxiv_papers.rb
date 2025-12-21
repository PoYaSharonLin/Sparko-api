# frozen_string_literal: true

require 'open3'
require 'json'
require 'fileutils'
require 'net/http'
require 'uri'

require_relative '../config/environment'
require_relative '../app/infrastructure/arxiv/gateways/arxiv_api'
require_relative '../app/presentation/view_objects/journal_options'
require_relative '../app/models/entities/summary'
require_relative '../app/domain/clustering/entities/query'
require_relative '../app/domain/clustering/entities/papers'
require_relative '../app/domain/clustering/entities/concepts'
require_relative '../app/domain/clustering/values/embedding'
require_relative '../app/domain/clustering/values/two_dim_embedding'
require_relative '../app/infrastructure/database/repositories/papers'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity

def wait_for_http_ok(url, timeout_seconds: 25, interval_seconds: 0.25)
  uri = URI(url)
  deadline = Time.now + timeout_seconds

  loop do
    begin
      Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)
        return true if res.is_a?(Net::HTTPSuccess)
      end
    rescue StandardError
      # keep trying
    end

    break if Time.now >= deadline
    sleep(interval_seconds)
  end

  false
end

def ensure_embed_service_for_release!
  embed_port = (ENV['EMBED_PORT'] || '8001').to_s
  embed_host = ENV['EMBED_HOST'] || '127.0.0.1'

  # Normalize EMBED_SERVICE_URL to BASE URL (scheme://host:port)
  raw = ENV['EMBED_SERVICE_URL'] || "http://#{embed_host}:#{embed_port}"
  uri = URI(raw)
  uri.scheme ||= 'http'
  uri.host ||= embed_host
  uri.port ||= embed_port.to_i

  base_url = "#{uri.scheme}://#{uri.host}:#{uri.port}"
  health_url = "#{base_url}/health"

  # Ensure the rest of the Ruby app always hits /embed
  ENV['EMBED_SERVICE_URL'] = "#{base_url}/embed"

  puts "[FETCH] Embed service health check: #{health_url}"
  puts "[FETCH] (Normalized) base_url=#{base_url} EMBED_SERVICE_URL=#{ENV['EMBED_SERVICE_URL']}"

  if wait_for_http_ok(health_url, timeout_seconds: 1, interval_seconds: 0.1)
    puts "[FETCH] Embed service already up ✅"
    return nil
  end

  python_bin = ENV['PYTHON_BIN'] || File.expand_path('./.venv/bin/python', __dir__)

  cache_root = File.expand_path('../tmp/hf_cache', __dir__)
  FileUtils.mkdir_p(cache_root)

  embed_env = {
    'PYTHONPATH' => '.',
    'PYTHON_BIN' => python_bin,

    'HF_HOME' => ENV['HF_HOME'] || cache_root,
    'HF_HUB_CACHE' => ENV['HF_HUB_CACHE'] || File.join(cache_root, 'hub'),
    'SENTENCE_TRANSFORMERS_HOME' => ENV['SENTENCE_TRANSFORMERS_HOME'] || File.join(cache_root, 'sentence_transformers'),
    'TRANSFORMERS_CACHE' => ENV['TRANSFORMERS_CACHE'] || cache_root, # deprecated

    # Force CPU unless overridden
    'EMBED_DEVICE' => ENV['EMBED_DEVICE'] || 'cpu',
    'TOKENIZERS_PARALLELISM' => ENV['TOKENIZERS_PARALLELISM'] || 'false',
    'OMP_NUM_THREADS' => ENV['OMP_NUM_THREADS'] || '1',
    'MKL_NUM_THREADS' => ENV['MKL_NUM_THREADS'] || '1',
    'PYTORCH_MPS_HIGH_WATERMARK_RATIO' => ENV['PYTORCH_MPS_HIGH_WATERMARK_RATIO'] || '0.5'
  }

  bind = "#{uri.host}:#{uri.port}"

  embed_cmd = [
    python_bin, '-m', 'gunicorn',
    '-w', (ENV['EMBED_WORKERS'] || '1'),
    '-k', (ENV['EMBED_GUNICORN_WORKER_CLASS'] || 'sync'),
    '--timeout', (ENV['EMBED_TIMEOUT'] || '120'),
    '-b', bind,
    'app.domain.clustering.services.embed_service:app'
  ]

  puts "[FETCH] Starting embed service for release on #{base_url} (bind=#{bind})"
  puts "[FETCH] cmd: #{embed_cmd.join(' ')}"
  puts "[FETCH] env: EMBED_DEVICE=#{embed_env['EMBED_DEVICE']} HF_HOME=#{embed_env['HF_HOME']}"

  pid = spawn(embed_env, *embed_cmd, out: $stdout, err: $stderr)

  unless wait_for_http_ok(health_url, timeout_seconds: 35)
    puts "[FETCH] ERROR: embed service did not become healthy at #{health_url}"
    begin
      Process.kill('KILL', pid)
    rescue Errno::ESRCH
    end
    raise "Embed service failed to boot for release (pid=#{pid})"
  end

  puts "[FETCH] Embed service healthy ✅ pid=#{pid}"
  pid
end


module AcaRadar
  # class for arxiv fetcher to fetch paper
  class ArxivFetcher
    def initialize
      @api = ArXivApi.new
      @journals = View::JournalOption.all
    end

    def run
      embed_pid = ensure_embed_service_for_release!

      at_exit do
        next unless embed_pid

        begin
          Process.kill('TERM', embed_pid)
          puts "[FETCH] Embed service stopped pid=#{embed_pid}"
        rescue Errno::ESRCH
        end
      end

      @journals.each do |journal|
        query = Query.new(journals: [journal[0]])
        fetch_and_process(query)
        sleep 5
      end

      puts 'Fetched and processed papers for all journals.'
      fit_pca_and_backfill_two_dim_embeddings!
      puts 'PCA fitted and 2D embeddings backfilled.'
    end

    private

    def fetch_and_process(query)
      api_response = @api.call(query)
      return unless api_response.ok?

      api_response.papers.each do |paper|
        concepts = Entity::Concept.extract_from(paper.summary.full_summary)
        embedding = Value::Embedding.embed_from(concepts.map(&:to_s).join(', '))

        Repository::Paper.create_or_update(
          origin_id: paper.origin_id,
          title: paper.title,
          published: paper.published,
          authors: paper.authors,
          summary: paper.summary.full_summary,
          short_summary: paper.summary.short_summary,
          concepts: concepts.map(&:to_s),
          embedding: embedding.full_embedding,
          two_dim_embedding: [], # placeholder; will be backfilled after PCA fit
          categories: paper.categories,
          links: paper.links,
          fetched_at: Time.now
        )
      rescue StandardError => e
        puts "Error processing paper #{paper.origin_id}: #{e.message}. Skipping paper."
      end
    rescue StandardError => e
      puts "Error fetching for arXiv api: #{e.message}. Skipping."
    end

    def fit_pca_and_backfill_two_dim_embeddings!
      pairs = Repository::Paper.origin_id_and_embeddings

      # Keep only valid embeddings with consistent dimension
      pairs = pairs.select { |p| p[:embedding].is_a?(Array) && p[:embedding].length >= 2 }
      return puts('Not enough embeddings to fit PCA (need >= 2).') if pairs.length < 2

      dim = pairs.first[:embedding].length
      pairs = pairs.select { |p| p[:embedding].length == dim }

      return puts('Not enough consistent-dimension embeddings to fit PCA.') if pairs.length < 2

      embeddings = pairs.map { |p| p[:embedding] }

      dim_reducer_path = ENV['DIM_REDUCER_PATH'] || 'app/domain/clustering/services/dimension_reducer.py'
      mean_path = ENV['PCA_MEAN_PATH'] || 'app/domain/clustering/services/pca_mean.json'
      comp_path = ENV['PCA_COMPONENTS_PATH'] || 'app/domain/clustering/services/pca_components.json'

      python = ENV.fetch('PYTHON_BIN', 'python3')
      stdout, stderr, status = Open3.capture3(
        { 'PCA_MEAN_PATH' => mean_path, 'PCA_COMPONENTS_PATH' => comp_path },
        python, dim_reducer_path,
        '--fit',
        '--mean-path', mean_path,
        '--components-path', comp_path,
        stdin_data: embeddings.to_json
      )

      raise "PCA fitting failed (dimension_reducer.py): #{stderr}" unless status.success?

      coords = JSON.parse(stdout)
      unless coords.is_a?(Array) && coords.length == pairs.length
        raise "PCA fitting returned unexpected output shape: expected #{pairs.length} rows, got #{coords.length}"
      end

      # Backfill 2D embeddings in DB
      pairs.each_with_index do |p, i|
        xy = coords[i]
        next unless xy.is_a?(Array) && xy.length == 2

        Repository::Paper.update_two_dim_embedding(p[:origin_id], xy)
      end
    rescue JSON::ParserError => e
      raise "Failed to parse PCA output JSON: #{e.message}"
    end
  end
end

AcaRadar::ArxivFetcher.new.run
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity
