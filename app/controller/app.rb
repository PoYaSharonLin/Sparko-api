# frozen_string_literal: true

require 'roda'
require 'slim'
require 'uri'
require_relative '../models/arxiv_api'
require_relative '../models/query'

# rubocop:disable Metrics/BlockLength
module AcaRadar
  # Web App
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/views'
    plugin :assets, css: 'style.css', path: 'app/views/assets'
    plugin :common_logger, $stderr
    plugin :halt

    # Initialize BEFORE route block (before freezing)
    ARXIV_API = ::AcaRadar::ArXivApi.new('config/secrets.yml')

    def self.arxiv_api
      ARXIV_API
    end

    route do |routing|
      routing.assets # load CSS
      response['Content-Type'] = 'text/html; charset=utf-8'

      # GET /
      routing.root do
        view 'home'
      end

      # GET /selected_journals
      routing.on 'selected_journals' do
        journal1 = routing.params['journal1']&.strip
        journal2 = routing.params['journal2']&.strip
        @journals = [journal1, journal2].reject(&:empty?)
        routing.halt 400, 'Please select at least 1 journal' if @journals.empty?

        begin
          query = AcaRadar::Query.new(journals: @journals)
          api = self.class.arxiv_api
          api_response = api.call(query)

          raise "arXiv API returned status #{api_response.status}" unless api_response.ok?

          @papers = api_response.papers
          @total_papers = api_response.total_results || papers.size

          @journal1_papers = papers.select do |paper|
            paper.journal_ref&.downcase&.include?(journal1.downcase)
          end
          @journal2_papers = papers.select do |paper|
            paper.journal_ref&.downcase&.include?(journal2.downcase)
          end

          @pagination = api_response.pagination

          view 'selected_journals'
        rescue StandardError => e
          @error = "Failed to fetch arXiv data: #{e.message}"
          view 'selected_journals'
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
