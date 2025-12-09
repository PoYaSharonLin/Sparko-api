# frozen_string_literal: true

require 'rack'
require 'roda'
require 'ostruct'
require 'logger'
require 'digest'

# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/ClassLength
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
        # /api/v1/research_interest...
        routing.on 'research_interest' do
          # POST /api/v1/research_interest
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

          # POST /api/v1/research_interest/async  (background job)
          routing.on 'async' do
            routing.post do
              request_obj = Request::EmbedResearchInterest.new(routing.params)

              unless request_obj.valid?
                response.status = 400
                return Response::BadRequest.new(
                  Representer::Error.generic('Research interest must be a non-empty string')
                ).to_json
              end

              result = Service::QueueResearchInterestEmbedding.new.call(term: request_obj.term)

              if result.failure?
                response.status = 500
                return Representer::Error.generic('Failed to queue embedding job').to_json
              end

              job_id = result.value!

              response.status = 202
              {
                status: 'processing',
                job_id: job_id,
                term: request_obj.term,
                status_url: "/api/v1/research_interest/#{job_id}"
              }.to_json
            end
          end

          # GET /api/v1/research_interest/:job_id  (check status)
          routing.get String do |job_id|
            job = Repository::ResearchInterestJob.find(job_id)

            unless job
              response.status = 404
              return Representer::Error.generic('Job not found').to_json
            end

            case job.status
            when 'completed'
              response.status = 200
              {
                status: 'completed',
                job_id: job.job_id,
                term: job.term,
                vector_2d: [job.vector_x, job.vector_y]
              }.to_json
            when 'failed'
              response.status = 500
              {
                status: 'failed',
                job_id: job.job_id,
                term: job.term,
                error: job.error_message
              }.to_json
            else
              response.status = 202
              {
                status: job.status,
                job_id: job.job_id,
                term: job.term
              }.to_json
            end
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

            cache_ttl = 300 # seconds

            cache_key_string = [
              request_obj.journals.sort.join(','),
              request_obj.page,
              session[:research_interest_term]
            ].join('|')

            etag_value = Digest::SHA256.hexdigest(cache_key_string)

            response['Cache-Control'] = "public, max-age=#{cache_ttl}"
            response['ETag']          = %("#{etag_value}")

            if env['HTTP_IF_NONE_MATCH'] == %("#{etag_value}")
              response.status = 304
              routing.halt
            end

            Representer::PapersPageResponse.new(response_obj).to_json
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/ClassLength
