# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'yaml'
require 'sequel'
require 'rack/session'

module AcaRadar
  # Configuration for the App
  class App < Roda
    plugin :environments

    if ENV['RACK_ENV'] == 'development' || ENV['RACK_ENV'] == 'test' || ENV['RACK_ENV'].nil?
      configure :development, :test do
        Figaro.application = Figaro::Application.new(
          environment:,
          path: File.expand_path('config/secrets_example.yml')
        )
        Figaro.load
        def self.config = Figaro.env
        # use scecret set by the env, use fall back
        use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET')
        CONFIG = YAML.safe_load_file('config/secrets_example.yml')
        ENV['DATABASE_URL'] ||= "sqlite://#{config.DB_FILENAME}"
      end
    end

    configure :production do
      CONFIG = YAML.safe_load_file('config/secrets_example.yml')
      def self.config = ENV
      use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET')
    end

    @db = Sequel.connect(ENV.fetch('DATABASE_URL'))
    def self.db = @db # rubocop:disable Style/TrivialAccessors
  end
end
