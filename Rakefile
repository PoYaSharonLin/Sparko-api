# frozen_string_literal: true

require 'rake/testtask'
require_relative 'require_app'

CODE = 'app/'

task :run do
  env = ENV['RACK_ENV'] || 'development'

  worker_cmd = [
    'bundle', 'exec', 'shoryuken',
    '-r', './config/shoryuken_boot.rb',
    '-C', 'config/shoryuken.yml'
  ]

  # Start Shoryuken in a separate process
  worker_pid = spawn({ 'RACK_ENV' => env }, *worker_cmd, out: $stdout, err: $stderr)
  puts "Shoryuken worker started with PID #{worker_pid}"

  # Make sure we clean up the worker when we exit Puma / Ctrl-C
  at_exit do
    Process.kill('TERM', worker_pid)
    puts "\nShoryuken worker (PID #{worker_pid}) terminated"
  rescue Errno::ESRCH
    # already dead, ignore
  end

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
