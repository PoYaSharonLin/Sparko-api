# frozen_string_literal: true

require 'rack'
require 'roda'
require 'ostruct'
require 'logger'

# rubocop:disable Metrics/BlockLength
module AcaRadar
  # class for applicatopm
  class App < Roda
    plugin :halt
    plugin :flash
    plugin :all_verbs
    plugin :json_parser
    plugin :sessions,
           secret: ENV.fetch('SESSION_SECRET', 'test_secret_at_least_64_bytes_long_for_security_purposes_in_production')

    APP_LOGGER = Logger.new($stdout)
    APP_LOGGER.level = Logger::DEBUG

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.root do
        message = "AcaRadar API v1 at /api/v1/ in #{App.environment} mode"
        result = Response::ApiResult.new(status: :ok, message: message)
        response.status = result.http_status_code
        result.to_json
      end

      routing.on 'api', 'v1' do
        # POST /api/v1/research_interest
        routing.on 'research_interest' do
          routing.post do
            request_obj = Request::EmbedResearchInterest.new(routing.params)

            unless request_obj.valid?
              response.status = 400
              return Response::BadRequest.new(
                Representer::Error.generic('Research interest must be a non-empty string')
              ).to_json
            end

            result = Service::EmbedResearchInterest.new.call(term: request_obj.term)

            if result.failure?
              response.status = 422
              return Representer::Error.generic('Failed to embed research interest').to_json
            end

            session[:research_interest_term] = request_obj.term
            session[:research_interest_2d]   = result.value!

            research_interest = OpenStruct.new(
              term: request_obj.term,
              vector_2d: result.value!
            )

            response.status = 201
            Response::Created.new(
              Representer::ResearchInterest.new(research_interest)
            ).to_json
          end
        end

        # GET /api/v1/papers
        routing.on 'papers' do
          routing.get do
            request_obj = Request::ListPapers.new(routing.params)

            unless request_obj.valid?
              message = if request_obj.journals.uniq.length < 2
                          'Please select two different journals'
                        else
                          'Invalid or unknown journals. Please use one of the allowed journals.'
                        end

              return Response::BadRequest.new(
                Representer::Error.generic(message)
              ).to_json
            end

            result = Service::ListPapers.new.call(
              journals: request_obj.journals,
              page: request_obj.page
            )

            if result.failure?
              response.status = 500
              return Representer::Error.generic('Failed to list papers').to_json
            end

            list = result.value!

            response_obj = OpenStruct.new(
              research_interest_term: session[:research_interest_term],
              research_interest_2d: session[:research_interest_2d],
              journals: request_obj.journals,
              papers: list
            )

            Representer::PapersPageResponse.new(response_obj).to_json
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
