# frozen_string_literal: true

require 'http'
require 'yaml'
require_relative '../helper/arxiv_api_parser'
require_relative 'categories'
require_relative 'authors'
require_relative 'papers'
require_relative 'query'

module AcaRadar
  module ArXivConfig
    BASE_QUERY = 'all:Reinforcement Learning'
    MIN_DATE_ARXIV = '201010020000'
    MAX_DATE_ARXIV = '202510020000'
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

      @next_call_time = Time.now.to_f + @cooldown_time + 0.1
      ArXivApiResponse.new(response.code, data_hash)
    rescue StandardError => error # rubocop:disable Naming/RescuedExceptionsVariableName
      raise "Failed to fetch or parse arXiv data: #{error.message}"
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
      @total_results = content_hash['total_results']&.to_i
      @start_index = content_hash['start_index']&.to_i
      @items_per_page = content_hash['items_per_page']&.to_i

      entries = content_hash['entries'] || []
      @papers = entries.map { |entry_hash| AcaRadar::Paper.new(entry_hash) }
    end

    def ok?
      (200..299).include?(@status)
    end

    def pagination
      { 'total_results' => @total_results,
        'start_index' => @start_index,
        'items_per_page' => @items_per_page }.compact
    end
  end
end
