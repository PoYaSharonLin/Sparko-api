# config.ru
# frozen_string_literal: true

require 'bundler/setup'
require 'rack/cache'
require 'redis'
require_relative 'require_app'
require_app

env = ENV.fetch('RACK_ENV', 'development')

if env == 'production'
  # Won't ever be executed because we will not go in production, so no production environment
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

  use Rack::Cache,
      verbose: true,
      metastore: "#{redis_url}/metastore",
      entitystore: "#{redis_url}/entitystore"
else
  # Development: file-based cache in tmp/cache
  FileUtils.mkdir_p('tmp/cache/meta')
  FileUtils.mkdir_p('tmp/cache/body')

  use Rack::Cache,
      verbose: true,
      metastore: 'file:tmp/cache/meta',
      entitystore: 'file:tmp/cache/body'
end

run AcaRadar::App.freeze.app
