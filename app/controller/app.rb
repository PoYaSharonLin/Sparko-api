# frozen_string_literal: true

require 'roda'
require 'slim'
require 'uri'
require 'rack'

# rubocop:disable Metrics/BlockLength
module AcaRadar
  # Web App
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/presentation/representers'
    plugin :assets, css: 'style.css', path: '/assets'
    plugin :static, ['/assets']
    plugin :common_logger, $stderr
    plugin :halt
    plugin :all_verbs
    plugin :flash

    MESSAGE = {
      embed_research_interest_ok: 'Research interest is sucessfully embedded!',
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

        # research interest from user should be a single term
        research_interest = routing.params['research_interest']&.strip
        if research_interest
          research_interest_form = AcaRadar::Form::ResearchInterest.new.call(single_term: research_interest)
          if research_interest_form.failure?
            flash[:error] = research_interest_form.errors[:single_term].first
            routing.redirect '/'
          end

          embedded_research_interest = AcaRadar::Service::EmbedResearchInterest.new.call(research_interest_form.to_h)
          if embedded_research_interest.failure?
            flash[:error] = embedded_research_interest.failure
            routing.redirect '/'
          end

          session[:research_interest_term] = research_interest
          session[:research_interest_2d] = embedded_research_interest.value!
          flash[:notice] = MESSAGE[:embed_research_interest_ok]
          routing.redirect '/'
        end

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
          page = routing.params['page']&.to_i || 1
          limit = 10
          offset = (page - 1) * limit

          papers = Repository::Paper.find_by_categories(journals, limit: limit, offset: offset)
          total_papers = Repository::Paper.count_by_categories(journals)

          total_pages = (total_papers.to_f / limit).ceil
          pagination = {
            current: page,
            total_pages: total_pages,
            prev_page: page > 1 ? page - 1 : nil,
            next_page: page < total_pages ? page + 1 : nil
          }

          session[:watching] |= papers.map(&:origin_id)

          view 'selected_journals',
               locals: { journals: journals, papers: papers.map do |p|
                 AcaRadar::View::Paper.new(p)
               end, total_papers: total_papers, pagination: pagination,
                         error: nil,
                         research_interest_term: session[:research_interest_term],
                         research_interest_2d: session[:research_interest_2d] }
        rescue StandardError => e
          view 'selected_journals',
               locals: { journals: journals, papers: [], total_papers: 0, pagination: {},
                         error: "Failed to fetch arXiv data: #{e.message}",
                         research_interest_term: session[:research_interest_term],
                         research_interest_2d: session[:research_interest_2d] }
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
