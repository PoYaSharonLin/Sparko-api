# frozen_string_literal: true

require 'rake/testtask'
require 'net/http'
require 'uri'
require 'fileutils'
require_relative 'require_app'

CODE = 'app/'

def wait_for_http(url, timeout_seconds: 20, interval_seconds: 0.25)
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
      # keep trying until deadline
    end

    break if Time.now >= deadline
    sleep(interval_seconds)
  end

  false
end

task :run do
  env = ENV['RACK_ENV'] || 'development'

  # ----------------------------
  # Embed service config
  # ----------------------------
  embed_port = (ENV['EMBED_PORT'] || '8001').to_s
  embed_host = ENV['EMBED_HOST'] || '127.0.0.1'
  embed_url  = ENV['EMBED_SERVICE_URL'] || "http://#{embed_host}:#{embed_port}"
  python_bin = ENV['PYTHON_BIN'] || File.expand_path('.venv/bin/python', __dir__)

  # HuggingFace cache dir 
  cache_root = File.expand_path('tmp/hf_cache', __dir__)
  FileUtils.mkdir_p(cache_root)

  embed_env = {
    'RACK_ENV' => env,
    'PYTHONPATH' => '.', # so app.domain... imports work
    'PYTHON_BIN' => python_bin,

    # HuggingFace cache env 
    'HF_HOME' => ENV['HF_HOME'] || cache_root,
    'HF_HUB_CACHE' => ENV['HF_HUB_CACHE'] || File.join(cache_root, 'hub'),
    'SENTENCE_TRANSFORMERS_HOME' => ENV['SENTENCE_TRANSFORMERS_HOME'] || File.join(cache_root, 'sentence_transformers'),

    # backwards compat (Transformers warns it's deprecated)
    'TRANSFORMERS_CACHE' => ENV['TRANSFORMERS_CACHE'] || cache_root,

    # Embed service binding
    'EMBED_PORT' => embed_port,
    'EMBED_SERVICE_URL' => embed_url,

    # ----------------------------
    # Stability knobs (IMPORTANT)
    # ----------------------------
    # Force CPU unless you explicitly override from shell
    'EMBED_DEVICE' => ENV['EMBED_DEVICE'] || 'cpu',

    # Avoid thread explosions inside tokenizers / BLAS
    'TOKENIZERS_PARALLELISM' => ENV['TOKENIZERS_PARALLELISM'] || 'false',
    'OMP_NUM_THREADS' => ENV['OMP_NUM_THREADS'] || '1',
    'MKL_NUM_THREADS' => ENV['MKL_NUM_THREADS'] || '1',

    # If MPS accidentally gets used, reduce chance of kill
    'PYTORCH_MPS_HIGH_WATERMARK_RATIO' => ENV['PYTORCH_MPS_HIGH_WATERMARK_RATIO'] || '0.5'
  }

puts "[RUN] Embed env: EMBED_DEVICE=#{embed_env['EMBED_DEVICE']} HF_HOME=#{embed_env['HF_HOME']} HUB=#{embed_env['HF_HUB_CACHE']}"


  # Gunicorn command for Flask app
  embed_cmd = [
    python_bin, '-m', 'gunicorn',
    '-w', (ENV['EMBED_WORKERS'] || '1'),
    '-k', (ENV['EMBED_GUNICORN_WORKER_CLASS'] || 'sync'),
    '--timeout', (ENV['EMBED_TIMEOUT'] || '120'),
    '-b', "0.0.0.0:#{embed_port}",
    'app.domain.clustering.services.embed_service:app'
  ]

  puts "[RUN] Embed cmd: #{embed_cmd.join(' ')}"


  # ----------------------------
  # Shoryuken config
  # ----------------------------
  worker_cmd = [
    'bundle', 'exec', 'shoryuken',
    '-r', './config/shoryuken_boot.rb',
    '-C', 'config/shoryuken.yml'
  ]

  # ----------------------------
  # Spawn embed service
  # ----------------------------
  puts "[RUN] Starting embed service on #{embed_url} (python=#{python_bin})"
  embed_pid = spawn(embed_env, *embed_cmd, out: $stdout, err: $stderr)
  puts "[RUN] Embed service started with PID #{embed_pid}"

  at_exit do
    begin
      Process.kill('TERM', embed_pid)
      puts "\n[RUN] Embed service (PID #{embed_pid}) terminated"
    rescue Errno::ESRCH
      # already dead
    end
  end

  # Wait until embed service is healthy before starting worker/web
  health_ok = wait_for_http("#{embed_url}/health", timeout_seconds: 300)
  unless health_ok
    puts "[RUN] ERROR: embed service health check failed at #{embed_url}/health"
    puts "[RUN] Killing embed PID #{embed_pid} and aborting."
    begin
      Process.kill('KILL', embed_pid)
    rescue Errno::ESRCH
    end
    exit(1)
  end
  puts "[RUN] Embed service healthy ✅"

  # ----------------------------
  # Spawn Shoryuken
  # ----------------------------
  worker_pid = spawn({ 'RACK_ENV' => env }.merge(embed_env), *worker_cmd, out: $stdout, err: $stderr)
  puts "[RUN] Shoryuken worker started with PID #{worker_pid}"

  at_exit do
    begin
      Process.kill('TERM', worker_pid)
      puts "\n[RUN] Shoryuken worker (PID #{worker_pid}) terminated"
    rescue Errno::ESRCH
      # already dead
    end
  end

  # ----------------------------
  # Start Puma (foreground)
  # ----------------------------
  sh "RACK_ENV=#{env} bundle exec puma"
end

task :default do
  puts `rake -T`
end

desc 'Run tests once'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.warning = false
end

desc 'Generates a 64 by secret for Rack::Session'
task :new_session_secret do
  require 'base64'
  require 'securerandom'
  secret = SecureRandom.random_bytes(64).then { Base64.urlsafe_encode64(it) }
  puts "SESSION_SECRET: #{secret}"
end

namespace :worker do
  desc 'Run Shoryuken worker (for current RACK_ENV)'
  task :run do
    env = ENV['RACK_ENV'] || 'development'
    sh "RACK_ENV=#{env} bundle exec shoryuken -r ./config/shoryuken_boot.rb -C config/shoryuken.yml"
  end
end

namespace :db do
  task :config do
    require 'sequel'
    require_relative 'config/environment'
    # require_relative 'spec/helpers/database_helper'

    def app = AcaRadar::App
  end

  desc 'Run migration'
  task migrate: :config do
    Sequel.extension :migration
    puts "Migrating #{app.environment} database to latest"
    Sequel::Migrator.run(app.db, 'db/migrations')
  end

  desc 'Wipe records from all tables'
  task wipe: :config do
    if app.environment == :production
      puts 'Do not damage the production database!'
      return
    end

    require_app(%w[models infrastructure])
    DatabaseHelper.wipe_database
  end

  desc 'Delete dev or test database file (set correct RACK_ENV)'
  task drop: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    FileUtils.rm(AcaRadar::App.config.DB_FILENAME)
    puts "Deleted #{AcaRadar::App.config.DB_FILENAME}"
  end
end

desc 'Run application console'
task :console do
  sh 'pry -r ./load_all'
end

namespace :vcr do
  desc 'delete cassette fixtures'
  task :wipe do
    sh 'rm spec/fixtures/cassettes/*.yml' do |ok, _|
      puts(ok ? 'Cassettes deleted' : 'No cassettes found')
    end
  end
end

namespace :cache do
  desc 'Wipe all cached API responses'
  task :wipe do
    cache_dir = File.expand_path('tmp/cache', __dir__)

    if Dir.exist?(cache_dir)
      puts "Deleting cache directory: #{cache_dir}"
      FileUtils.rm_rf(cache_dir)
      puts '✔ Cache wiped.'
    else
      puts "No cache directory found at #{cache_dir}."
    end
  end
end

namespace :quality do
  desc 'run all static-analysis quality checks'
  task all: %i[rubocop reek flog]

  desc 'code style linter'
  task :rubocop do
    sh 'rubocop'
  end

  desc 'code smell detector'
  task :reek do
    sh 'reek'
  end

  desc 'complexity analysis'
  task :flog do
    sh "flog #{CODE}"
  end
end
