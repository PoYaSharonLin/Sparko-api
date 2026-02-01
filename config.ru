# config.ru
# frozen_string_literal: true

require 'bundler/setup'
require 'rack/cache'
require 'redis'
require 'faye'
require 'rack/cors'
require 'fileutils'
require_relative 'require_app'
require_app

Faye::WebSocket.load_adapter('puma')
env = ENV.fetch('RACK_ENV', 'development')

use Rack::Cors do
  allow do
    # Development origins
    allowed_origins = [
      'localhost:9000', '127.0.0.1:9000',
      'localhost:9292', '127.0.0.1:9292',
      # Heroku (legacy)
      'https://acaradar-app-3bd1e48033fd.herokuapp.com',
      # Railway - will be set via ALLOWED_ORIGINS env var
      ENV['RAILWAY_PUBLIC_DOMAIN'] ? "https://#{ENV['RAILWAY_PUBLIC_DOMAIN']}" : nil,
      # Custom allowed origins from env
      *(ENV['ALLOWED_ORIGINS']&.split(',') || [])
    ].compact

    origins(*allowed_origins)
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options],
             credentials: true,
             max_age: 86400
  end
end

# IMPORTANT: mount Faye as middleware so /faye/client.js works
use Faye::RackAdapter, mount: '/faye', timeout: 25

# Cache only applies to requests that Faye doesn't intercept
if env == 'production'
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  use Rack::Cache,
      verbose: true,
      metastore: "#{redis_url}/metastore",
      entitystore: "#{redis_url}/entitystore"
else
  FileUtils.mkdir_p('tmp/cache/meta')
  FileUtils.mkdir_p('tmp/cache/body')

  use Rack::Cache,
      verbose: true,
      metastore: 'file:tmp/cache/meta',
      entitystore: 'file:tmp/cache/body'
end

run Sparko::App.freeze.app
