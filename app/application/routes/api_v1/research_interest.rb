# frozen_string_literal: true

require 'digest'
require 'base64'
require 'json'

module Sparko
  module Routes
    # Research Interest routes - /api/v1/research_interest
    module ResearchInterest
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def handle_research_interest_route(routing)
        routing.on 'research_interest' do
          # POST /api/v1/research_interest
          routing.post do
            request_obj = Request::EmbedResearchInterest.new(routing.params)

            unless request_obj.valid?
              data = { error_code: request_obj.error_code, error: request_obj.error_message }
              standard_response(:bad_request, request_obj.error_message, data)
            end

            result = Service::QueueResearchInterestEmbedding.new.call(term: request_obj.term)
            standard_response(:internal_error, 'Failed to queue embedding job') if result.failure?

            job_id = result.value!
            job = Repository::ResearchInterestJob.find(job_id)

            if job && job.status == 'completed'
              store_completed_job_in_session(job, job_id)
              concepts = parse_concepts(job.concepts_json)

              data = {
                cached: true,
                status: 'completed',
                request_id: job_id,
                term: job.term,
                concepts: concepts,
                vector_2d: [job.vector_x.to_f, job.vector_y.to_f],
                status_url: "/api/v1/research_interest/#{job_id}",
                percent: 100,
                message: 'Cached'
              }

              standard_response(:ok, 'Research interest already embedded', data)
            end

            # Not completed -> treat as queued/processing
            session[:research_interest_request_id] = job_id
            session[:research_interest_term] = request_obj.term
            session.delete(:research_interest_2d)
            session.delete(:research_interest_embedding_b64)

            Sparko.logger.debug("RI queued job_id=#{job_id} term=#{request_obj.term.inspect}")

            data = {
              message: 'Queued',
              percent: 1,
              request_id: job_id,
              status: (job&.status || 'queued'),
              status_url: "/api/v1/research_interest/#{job_id}"
            }

            standard_response(:processing, 'Research interest processing started', data)
          end

          # POST /api/v1/research_interest/async
          routing.on 'async' do
            routing.post do
              request_obj = Request::EmbedResearchInterest.new(routing.params)
              unless request_obj.valid?
                data = { error_code: request_obj.error_code, error: request_obj.error_message }
                standard_response(:bad_request, request_obj.error_message, data)
              end

              normalized = normalize_term(request_obj.term)
              cached_job = find_cached_completed_job_by_term(normalized)

              if cached_job
                Sparko.logger.info("Async RI cache hit for #{normalized}")
                store_completed_job_in_session(cached_job, cached_job.job_id)

                data = {
                  cached: true,
                  status: 'completed',
                  request_id: cached_job.job_id,
                  term: cached_job.term,
                  vector_2d: [cached_job.vector_x.to_f, cached_job.vector_y.to_f],
                  status_url: "/api/v1/research_interest/#{cached_job.job_id}"
                }

                standard_response(:ok, 'Research interest already embedded', data)
              end

              result = Service::QueueResearchInterestEmbedding.new.call(term: request_obj.term)
              standard_response(:internal_error, 'Failed to queue embedding job') if result.failure?

              job_id = result.value!

              session[:research_interest_request_id] = job_id
              session[:research_interest_term] = request_obj.term
              session.delete(:research_interest_2d)
              session.delete(:research_interest_embedding_b64)

              Sparko.logger.debug("RI async queued job_id=#{job_id} term=#{request_obj.term.inspect}")

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

            # HTTP caching for polling (ETag)
            etag_value = compute_job_etag(job)

            response['Cache-Control'] = 'private, max-age=10'
            response['Vary'] = 'Cookie'
            response['ETag'] = %("#{etag_value}")

            if env['HTTP_IF_NONE_MATCH'] == %("#{etag_value}")
              standard_response(:not_modified, 'Not Modified')
            end

            Sparko.logger.debug("RI status check job_id=#{job_id} status=#{job.status.inspect}")

            case job.status
            when 'completed'
              store_completed_job_in_session(job, job.job_id)
              concepts = parse_concepts(job.concepts_json)
              Sparko.logger.info("RI Job Completed. ID: #{job_id}, Concepts: #{concepts.inspect}")

              data = {
                status: 'completed',
                job_id: job.job_id,
                term: job.term,
                vector_2d: [job.vector_x.to_f, job.vector_y.to_f],
                concepts: concepts
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
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      private

      def store_completed_job_in_session(job, job_id)
        session[:research_interest_request_id] = job_id
        session[:research_interest_term] = job.term
        session[:research_interest_2d] = [job.vector_x.to_f, job.vector_y.to_f]

        if job.respond_to?(:embedding_b64) && job.embedding_b64 && !job.embedding_b64.to_s.empty?
          session[:research_interest_embedding_b64] = job.embedding_b64
        else
          session.delete(:research_interest_embedding_b64)
        end
      end

      def compute_job_etag(job)
        etag_src = [
          job.job_id,
          job.status,
          (job.updated_at&.to_i || 0),
          (job.vector_x || 0),
          (job.vector_y || 0),
          (job.respond_to?(:embedding_dim) ? job.embedding_dim.to_i : 0)
        ].join('|')
        Digest::SHA256.hexdigest(etag_src)
      end

      def parse_concepts(concepts_json)
        JSON.parse(concepts_json.to_s)
      rescue StandardError => e
        Sparko.logger.error("Concepts parse error: #{e.class} - #{e.message}")
        []
      end
    end
  end
end
