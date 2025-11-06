# frozen_string_literal: true

require 'roda'
require 'slim'
require 'uri'
require 'rack'
require_relative '../infrastructure/arxiv/gateways/arxiv_api'
require_relative '../domain/clustering/entities/query'

# rubocop:disable Metrics/BlockLength
module AcaRadar
  # Web App
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/presentation/views_slim'
    plugin :assets, css: 'style.css', path: '/assets'
    plugin :static, ['/assets']
    plugin :common_logger, $stderr
    plugin :halt
    plugin :all_verbs
    plugin :sessions, secret: ENV.fetch('SESSION_SECRET', nil)
    plugin :flash

    MESSAGE = {
      refuse_same_journal: 'Please select 2 different journals',
      api_error: 'arxiv API is not responsing, please visit the website later'
    }.freeze

    route do |routing|
      routing.assets
      response['Content-Type'] = 'text/html; charset=utf-8'

      # GET /
      routing.root do
        # display papers in previous session
        session[:watching] ||= []
        watched_papers = Repository::Paper.find_many_by_ids(session[:watching])
        journal_options = AcaRadar::View::JournalOption.new
        view 'home', locals: { watched_papers: watched_papers, options: journal_options }
      end

      # GET /selected_journals
      routing.on 'selected_journals' do
        first_journal = routing.params['journal1']&.strip
        second_journal = routing.params['journal2']&.strip
        if first_journal == second_journal
          flash[:notice] = MESSAGE[:refuse_same_journal]
          routing.redirect '/'
        end
        journals = [first_journal, second_journal].compact.reject(&:empty?)

        begin
          query = AcaRadar::Query.new(journals: journals)
          api = AcaRadar::ArXivApi.new
          api_response = api.call(query)

          flash.now[:notice] = MESSAGE[:api_error] unless api_response.ok?

          papers = api_response.papers
          total_papers = api_response.total_results || papers.size
          pagination = api_response.pagination
          # store papers' ids to display at home next time
          papers.each do |paper|
            Repository::Paper.db_find_or_create(paper)
          end
          session[:watching] |= papers.map(&:origin_id)

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
