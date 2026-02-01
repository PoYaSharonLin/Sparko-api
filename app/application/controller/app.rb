# frozen_string_literal: true

require 'rack'
require 'roda'
require 'ostruct'
require 'logger'
require 'digest'
require 'base64'
require 'yaml'
require_relative '../../infrastructure/utilities/logger'
require_relative '../routes/api_v1/research_interest'
require_relative '../routes/api_v1/papers'
require_relative '../routes/api_v1/journals'

module Sparko
  # Application Controller (API)
  #
  # Routes are decomposed into modules in app/application/routes/api_v1/:
  # - research_interest.rb - handles /api/v1/research_interest endpoints
  # - papers.rb - handles /api/v1/papers endpoints
  # - journals.rb - handles /api/v1/journals endpoints
  class App < Roda
    include Routes::ResearchInterest
    include Routes::Papers
    include Routes::Journals

    plugin :halt
    plugin :flash
    plugin :all_verbs
    plugin :json_parser
    plugin :sessions,
           secret: ENV.fetch('SESSION_SECRET', 'test_secret_at_least_64_bytes_long'),
           key: 'sparko.session',
           cookie_options: {
             same_site: :none,
             secure: false,
             httponly: true
           }

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.root do
        standard_response(
          :ok,
          "Sparko API v1 at /api/v1/ in #{App.environment} mode"
        )
      end

      routing.on 'api', 'v1' do
        # Research Interest routes: /api/v1/research_interest
        handle_research_interest_route(routing)

        # Papers routes: /api/v1/papers
        handle_papers_route(routing)

        # Journals routes: /api/v1/journals
        handle_journals_route(routing)
      end
    end

    private

    def standard_response(status_sym, message, data = nil)
      response_wrapper = Response::HttpResponse.new(
        status: status_sym,
        message: message,
        data: data
      )

      response.status = response_wrapper.code
      request.halt response.status, response_wrapper.to_json
    end

    # iOS-friendly response with meta field and ISO 8601 timestamps
    # Use this for new iOS endpoints in Milestone B+
    def ios_response(status_sym, message, data = nil, meta: nil, cache_max_age: nil)
      response_wrapper = Response::ApiResponse.new(
        status: status_sym,
        message: message,
        data: data,
        meta: meta
      )

      # Apply cache headers if specified
      if cache_max_age
        response_wrapper.apply_cache_headers(response, max_age: cache_max_age)
      end

      response.status = response_wrapper.code
      request.halt response.status, response_wrapper.to_json
    end

    def normalize_term(term)
      term.to_s.strip.downcase.gsub(/\s+/, ' ')
    end

    # Uses the DB as the local cache for completed research interest jobs
    def find_cached_completed_job_by_term(normalized_term)
      return nil if normalized_term.empty?
      return nil unless defined?(Sparko::Database::ResearchInterestJobOrm)

      Sparko::Database::ResearchInterestJobOrm
        .where(status: 'completed')
        .where(Sequel.function(:lower, :term) => normalized_term)
        .order(Sequel.desc(:updated_at))
        .first
    rescue StandardError => e
      Sparko.logger.warn("RI cache lookup failed term=#{normalized_term.inspect}: #{e.class} - #{e.message}")
      nil
    end
  end
end
