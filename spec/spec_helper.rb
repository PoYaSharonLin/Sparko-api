# frozen_string_literal: true

require 'yaml'
require 'minitest/autorun'
require 'minitest/rg'
require 'vcr'
require 'webmock'
require 'simplecov'

require_relative '../lib/arxiv_api'
require_relative '../helper/arxiv_api_parser'

CONFIG = YAML.safe_load_file('config/secrets.yml', aliases: true)
CORRECT = YAML.safe_load_file('spec/fixtures/arxiv_results.yml', aliases: true)

CASSETTES_FOLDER = 'spec/fixtures/cassettes'
CASSETTE_FILE = 'arxiv_api'

SimpleCov.start
