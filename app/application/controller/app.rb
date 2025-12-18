# frozen_string_literal: true

require 'rack'
require 'roda'
require 'ostruct'
require 'logger'
require 'digest'

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/BlockLength
module AcaRadar
  # Application Controller
  class App < Roda
    plugin :halt
    plugin :flash
    plugin :all_verbs
    plugin :json_parser
    plugin :sessions,
           secret: ENV.fetch('SESSION_SECRET', 'test_secret_at_least_64_bytes_long')

    APP_LOGGER = Logger.new($stdout)
    APP_LOGGER.level = Logger::DEBUG

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.root do
        standard_response(
          :ok,
          "AcaRadar API v1 at /api/v1/ in #{App.environment} mode"
        )
      end

      routing.on 'api', 'v1' do
        routing.on 'research_interest' do
          # POST /api/v1/research_interest
          routing.post do
            request_obj = Request::EmbedResearchInterest.new(routing.params)
            standard_response(:bad_request, 'Research interest must be a non-empty string') unless request_obj.valid?

            request_id = [request_obj, Time.now.to_f].hash.to_s

            Thread.new do
              begin
                Service::EmbedResearchInterest.new.call(
                  term: request_obj.term,
                  request_id: request_id
                )
              rescue StandardError => e
                APP_LOGGER.error "BACKGROUND_JOB_ERROR: #{e.message}"
                APP_LOGGER.error e.backtrace.join("\n")
              end
            end

            data = { 
              message: 'Processing started', 
              request_id: request_id 
            }
            
            standard_response(:processing, 'Research interest processing started', data)
          end

          # POST /api/v1/research_interest/async
          routing.on 'async' do
            routing.post do
              request_obj = Request::EmbedResearchInterest.new(routing.params)
              standard_response(:bad_request, 'Research interest must be a non-empty string') unless request_obj.valid?

              result = Service::QueueResearchInterestEmbedding.new.call(term: request_obj.term)
              standard_response(:internal_error, 'Failed to queue embedding job') if result.failure?

              job_id = result.value!
              data = {
                job_id: job_id,
                term: request_obj.term,
                status_url: "/api/v1/research_interest/#{job_id}"
              }
              standard_response(:processing, 'Job queued', data)
            end
          end

          # GET /api/v1/research_interest/:job_id
          routing.get String do |job_id|
            job = Repository::ResearchInterestJob.find(job_id)
            standard_response(:not_found, 'Job not found') unless job

            case job.status
            when 'completed'
              session[:research_interest_term] = job.term
              session[:research_interest_2d] = [job.vector_x, job.vector_y]
              data = {
                status: 'completed',
                job_id: job.job_id,
                term: job.term,
                vector_2d: [job.vector_x, job.vector_y]
              }
              standard_response(:ok, 'Job completed', data)
            when 'failed'
              data = { status: 'failed', job_id: job.job_id, error: job.error_message }
              standard_response(:internal_error, 'Job failed', data)
            else
              data = { status: job.status, job_id: job.job_id }
              standard_response(:processing, 'Job processing', data)
            end
          end
        end

        # GET /api/v1/papers
        routing.on 'papers' do
          routing.get do
            request_obj = Request::ListPapers.new(routing.params)

            unless request_obj.valid?
              msg = if request_obj.journals.uniq.length < 2
                      'Please select two different journals'
                    else
                      'Invalid or unknown journals.'
                    end
              standard_response(:bad_request, msg)
            end

            result = Service::ListPapers.new.call(
              journals: request_obj.journals,
              page: request_obj.page,
              research_embedding: session[:research_interest_embedding]
            )
            
            standard_response(:internal_error, 'Failed to list papers') if result.failure?

            list = result.value!

            # Caching Logic
            cache_ttl = 300
            cache_key = [
              request_obj.journals.sort.join(','),
              request_obj.page,
              session[:research_interest_term]
            ].join('|')
            etag_value = Digest::SHA256.hexdigest(cache_key)

            response['Cache-Control'] = "public, max-age=#{cache_ttl}"
            response['ETag']          = %("#{etag_value}")

            standard_response(:not_modified, 'Not Modified') if env['HTTP_IF_NONE_MATCH'] == %("#{etag_value}")

            # Prepare Data
            response_obj = OpenStruct.new(
              research_interest_term: session[:research_interest_term],
              research_interest_2d: research_interest_2d,
              journals: request_obj.journals,
              papers: list
            )
            data = Representer::PapersPageResponse.new(response_obj)

            standard_response(:ok, 'Papers retrieved successfully', data)
          end
        end
      end
    end

    private

    # Helper method to enforce the HttpResponse pattern
    def standard_response(status_sym, message, data = nil)
      response_wrapper = Response::HttpResponse.new(
        status: status_sym,
        message: message,
        data: data
      )

      response.status = response_wrapper.code
      request.halt response.status, response_wrapper.to_json
    end
  end
end
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/BlockLength
