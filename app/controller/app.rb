# frozen_string_literal: true

require 'roda'
require 'slim'
require 'uri'
require_relative '../infrastructure/arxiv/gateways/arxiv_api'
require_relative '../domain/clustering/entities/query'

# rubocop:disable Metrics/BlockLength
module AcaRadar
  # Web App
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/views'
    plugin :assets, css: 'style.css', path: 'app/views/assets'
    plugin :common_logger, $stderr
    plugin :halt

    route do |routing|
      routing.assets # load CSS
      response['Content-Type'] = 'text/html; charset=utf-8'

      # GET /
      routing.root do
        view 'home'
      end

      # GET /selected_journals
      routing.on 'selected_journals' do
        first_journal = routing.params['journal1']&.strip
        second_journal = routing.params['journal2']&.strip
        journals = [first_journal, second_journal].compact.reject(&:empty?)
        routing.halt 400, 'Please select at least 1 journal' if journals.empty?

        begin
          query = AcaRadar::Query.new(journals: journals)
          api = AcaRadar::ArXivApi.new
          api_response = api.call(query)

          raise "arXiv API returned status #{api_response.status}" unless api_response.ok?

          papers = api_response.papers
          total_papers = api_response.total_results || papers.size
          pagination = api_response.pagination

          view 'selected_journals',
               locals: { journals: journals, papers: papers, total_papers: total_papers, pagination: pagination,
                         error: nil }
        rescue StandardError => e
          view 'selected_journals',
               locals: { journals: journals, papers: [], total_papers: 0, pagination: {},
                         error: "Failed to fetch arXiv data: #{e.message}" }
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
