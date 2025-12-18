# frozen_string_literal: true

require 'open3'
require 'json'

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

module AcaRadar
  # class for arxiv fetcher to fetch paper
  class ArxivFetcher
    def initialize
      @api = ArXivApi.new
      @journals = View::JournalOption.all
    end

    def run
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

        # IMPORTANT: do NOT compute 2D here anymore
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

      stdout, stderr, status = Open3.capture3(
        { 'PCA_MEAN_PATH' => mean_path, 'PCA_COMPONENTS_PATH' => comp_path },
        'python3', dim_reducer_path,
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
