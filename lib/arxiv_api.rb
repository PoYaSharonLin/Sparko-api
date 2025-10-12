# frozen_string_literal: true

require 'http'
require 'yaml'
require_relative '../helper/arxiv_api_parser'
require_relative 'excerpts'
require_relative 'categories'
require_relative 'publications'
require_relative 'authors'

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
    include ArXivConfig
    def initialize(config_path = 'config/secrets.yml')
      @config = YAML.safe_load_file(config_path)
      @parser = AcaRadar::ArXivApiParser.new
      @params = build_query_params
    end

    def excerpts
      fetch_and_parse(Excerpt)
    end

    def categories
      fetch_and_parse(Category)
    end

    def publications
      fetch_and_parse(Publication)
    end

    def authors
      fetch_and_parse(Author)
    end

    private

    def build_query_params
      query = "#{BASE_QUERY} AND submittedDate:[#{MIN_DATE_ARXIV} TO #{MAX_DATE_ARXIV}]"
      URI.encode_www_form(
        'search_query' => query,
        'start' => 0,
        'max_results' => MAX_RESULTS,
        'sortBy' => SORT_BY,
        'sortOrder' => SORT_ORDER
      )
    end

    def fetch_and_parse(klass)
      url = @parser.arxiv_api_path("query?#{@params}")
      response = @parser.call_arxiv_url(@config, url)
      atom = response.to_s
      parsed = @parser.parse_arxiv_atom(atom)
      klass.new(parsed['entries'] || parsed)
    rescue StandardError => e
      raise "Failed to fetch or parse arXiv data: #{e.message}"
    end
  end
end
