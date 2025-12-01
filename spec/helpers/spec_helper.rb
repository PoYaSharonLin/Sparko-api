# frozen_string_literal: true

require 'yaml'
require 'minitest/autorun'
require 'minitest/rg'
require 'vcr'
require 'webmock'
require 'simplecov'
require 'sequel'

require_relative '../../require_app'
require_app

CONFIG = YAML.safe_load_file('config/secrets_example.yml', aliases: true)
CORRECT = YAML.safe_load_file('spec/fixtures/arxiv_results.yml', aliases: true)

CASSETTES_FOLDER = 'spec/fixtures/cassettes'
CASSETTE_FILE = 'arxiv_api'

SimpleCov.start
