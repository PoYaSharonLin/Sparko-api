# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'yaml'
require 'sequel'
require 'rack/session'

module Sparko
  class App < Roda
    plugin :environments

    # ---------------------------
    # DEVELOPMENT ENVIRONMENT
    # ---------------------------
    configure :development do
      Figaro.application = Figaro::Application.new(
        environment:,
        path: File.expand_path('config/secrets.yml')  # dev uses secrets.yml
      )
      Figaro.load

      def self.config = Figaro.env

      use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET')
      CONFIG = YAML.safe_load_file('config/secrets.yml')
      ENV['DATABASE_URL'] ||= "sqlite://#{config.DB_FILENAME}"
      # Sparko-api/tmp/hf_cache
    end

    # ---------------------------
    # TEST ENVIRONMENT  (CI)
    # ---------------------------
    configure :test do
      Figaro.application = Figaro::Application.new(
        environment:,
        path: File.expand_path('config/secrets.yml')
      )
      Figaro.load

      def self.config = Figaro.env

      CONFIG = {} #hotfix because the tests require it
      use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET')
      ENV['DATABASE_URL'] ||= "sqlite://#{config.DB_FILENAME}"
    end

    # ---------------------------
    # PRODUCTION (Heroku)
    # ---------------------------
    configure :production do
      def self.config = ENV

      CONFIG = {} #hotfix because the tests require it
      use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET')
    end

    @db = Sequel.connect(ENV.fetch('DATABASE_URL'))
    def self.db = @db
  end
end
