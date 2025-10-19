# frozen_string_literal: true

require 'http'
require 'yaml'
require_relative '../../../helper/arxiv_api_parser'
require_relative '../entities/categories'
require_relative '../entities/authors'
require_relative '../entities/papers'
require_relative '../entities/query'

module AcaRadar
  # :reek:TooManyConstants
  module ArXivConfig
    MIN_DATE_ARXIV = '201010020000'
    MAX_DATE_ARXIV = '202510020000'
    JOURNALS = [].freeze
    MAX_RESULTS = 50
    SORT_BY = 'submittedDate'
    SORT_ORDER = 'ascending'
  end

  # Library for arXiv Web API
  class ArXivApi
    def initialize(config_path = 'config/secrets.yml', cooldown_time = 3)
      @config = YAML.safe_load_file(config_path)
      @parser = AcaRadar::ArXivApiParser.new
      @next_call_time = 0
      @cooldown_time = cooldown_time
    end

    def call(query_obj)
      wait_cooldown
      url = query_obj.url
      response = @parser.call_arxiv_url(@config, url)
      data_hash = @parser.parse_arxiv_atom(response.body.to_s)
      data_hash['entries'] || []
      @next_call_time = Time.now.to_f + @cooldown_time + 0.1
      ArXivApiResponse.new(response.code, data_hash)
    rescue StandardError => e
      raise "Failed to fetch or parse arXiv data: #{e.message}"
    end

    private

    def wait_cooldown
      delay = @next_call_time - Time.now.to_f
      sleep(delay) if delay.positive?
    end
  end

  # Represents the response given by the API with some metadata
  class ArXivApiResponse
    attr_reader :status, :total_results, :start_index, :items_per_page, :papers

    def initialize(status_code, content_hash)
      @status = status_code.to_i
      # group pagination values into one ivar to reduce instance var count
      @pagination = build_pagination(content_hash)
      entries = content_hash['entries'] || []
      @papers = entries.map { |entry_hash| AcaRadar::Paper.new(entry_hash) }
    end

    def ok?
      (200..299).include?(@status)
    end

    def pagination
      @pagination.transform_keys(&:to_s)
    end

    private

    def build_pagination(content_hash)
      {
        total_results: extract_integer(content_hash, %w[total_results totalResults]),
        start_index: extract_integer(content_hash, %w[start_index startIndex]),
        items_per_page: extract_integer(content_hash, %w[items_per_page itemsPerPage])
      }.compact
    end

    def extract_integer(hash, keys)
      value = keys.map { |key| hash[key] }.compact.first || 0
      value.to_i
    end
  end
end
