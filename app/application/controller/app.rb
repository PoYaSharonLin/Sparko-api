# frozen_string_literal: true

require 'rack'
require 'roda'
require 'ostruct'
require 'logger'
require 'digest'
require 'base64'
require_relative '../../infrastructure/utilities/logger'

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/BlockLength
module AcaRadar
  # Application Controller (API)
  class App < Roda
    plugin :halt
    plugin :flash
    plugin :all_verbs
    plugin :json_parser
    plugin :sessions,
           secret: ENV.fetch('SESSION_SECRET', 'test_secret_at_least_64_bytes_long'),
           key: 'acaradar.session',
           cookie_options: {
             same_site: :none,
             secure: false, # NOTE: browsers reject SameSite=None unless Secure=true
             httponly: true
           }

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
          # fast response; heavy work happens in Shoryuken worker.
          routing.post do
            request_obj = Request::EmbedResearchInterest.new(routing.params)
          
            unless request_obj.valid?
              data = { error_code: request_obj.error_code, error: request_obj.error_message }
              standard_response(:bad_request, request_obj.error_message, data)
            end

            # Single entrypoint for caching/idempotency/queueing
            result = Service::QueueResearchInterestEmbedding.new.call(term: request_obj.term)
            standard_response(:internal_error, 'Failed to queue embedding job') if result.failure?
          
<<<<<<< HEAD
            job_id = result.value!
            job    = Repository::ResearchInterestJob.find(job_id)
            
            # If the service returned a cached completed job, respond immediately as "completed"
            if job && job.status == 'completed'
              session[:research_interest_request_id] = job_id
              session[:research_interest_term]       = job.term
              session[:research_interest_2d]         = [job.vector_x.to_f, job.vector_y.to_f]
=======
            # job_id = result.value!
            job    = Repository::ResearchInterestJob.find(job_id)
            
            # If the service returned a cached completed job, respond immediately as "completed"
            # if job && job.status == 'completed'
            #   session[:research_interest_request_id] = job_id
            #   session[:research_interest_term]       = job.term
            #   session[:research_interest_2d]         = [job.vector_x.to_f, job.vector_y.to_f]
>>>>>>> 19d5913 (uncomment job)
          
              if job.respond_to?(:embedding_b64) && job.embedding_b64 && !job.embedding_b64.to_s.empty?
                session[:research_interest_embedding_b64] = job.embedding_b64
              else
                session.delete(:research_interest_embedding_b64)
              end

              concepts =
                begin
                  c = JSON.parse(job.concepts_json.to_s)
                  AcaRadar.logger.info("SPECIAL DEBUG: ... Concepts available: #{c.inspect}")
                  c
                rescue StandardError => e
                  AcaRadar.logger.error("SPECIAL DEBUG: concepts parse error (cached): #{e.class} - #{e.message}")
                  []
                end
  
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
            job_id = SecureRandom.uuid

            Thread.new do
              Service::EmbedResearchInterest.new.call(
                term: request_obj.term, 
                request_id: job_id
              )
            rescue StandardError => e
              AcaRadar.logger.error("Publisher thread error: #{e.message}")
            end

            session[:research_interest_request_id] = job_id
            session[:research_interest_term]       = request_obj.term
            session.delete(:research_interest_2d)
            session.delete(:research_interest_embedding_b64)
          
            AcaRadar.logger.debug("RI queued job_id=#{job_id} term=#{request_obj.term.inspect}")
          
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
          # Kbackwards compatibility; same behavior as POST /research_interest.
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
                
                AcaRadar.logger.info("SPECIAL DEBUG: Async RI cache hit for #{normalized}")

                job_id = cached_job.job_id
              
                session[:research_interest_request_id] = job_id
                session[:research_interest_term]       = cached_job.term
                session[:research_interest_2d]         = [cached_job.vector_x.to_f, cached_job.vector_y.to_f]
                session[:research_interest_embedding_b64] = cached_job.embedding_b64 if cached_job.embedding_b64 && !cached_job.embedding_b64.to_s.empty?
              
                data = {
                  cached: true,
                  status: 'completed',
                  request_id: job_id,
                  term: cached_job.term,
                  vector_2d: [cached_job.vector_x.to_f, cached_job.vector_y.to_f],
                  status_url: "/api/v1/research_interest/#{job_id}"
                }
              
                standard_response(:ok, 'Research interest already embedded', data)
              end             

              result = Service::QueueResearchInterestEmbedding.new.call(term: request_obj.term)
              standard_response(:internal_error, 'Failed to queue embedding job') if result.failure?

              job_id = result.value!

              session[:research_interest_request_id] = job_id
              session[:research_interest_term]       = request_obj.term
              session.delete(:research_interest_2d)
              session.delete(:research_interest_embedding_b64)

              AcaRadar.logger.debug("RI async queued job_id=#{job_id} term=#{request_obj.term.inspect}")

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

            # ----------------------------
            # HTTP caching for polling (ETag)
            # ----------------------------
            cache_ttl = 10
            etag_src = [
              job.job_id,
              job.status,
              (job.updated_at&.to_i || 0),
              (job.vector_x || 0),
              (job.vector_y || 0),
              (job.respond_to?(:embedding_dim) ? job.embedding_dim.to_i : 0)
            ].join('|')
            etag_value = Digest::SHA256.hexdigest(etag_src)

            response['Cache-Control'] = "private, max-age=#{cache_ttl}"
            response['Vary']          = 'Cookie'
            response['ETag']          = %("#{etag_value}")

            if env['HTTP_IF_NONE_MATCH'] == %("#{etag_value}")
              standard_response(:not_modified, 'Not Modified')
            end

            AcaRadar.logger.debug("RI status check job_id=#{job_id} status=#{job.status.inspect}")

            case job.status
            when 'completed'
              # These are what the front-end uses for plotting
              session[:research_interest_term]       = job.term
              session[:research_interest_2d]         = [job.vector_x.to_f, job.vector_y.to_f]
              session[:research_interest_request_id] = job.job_id

              # Store embedding b64 in session if present 
              if job.respond_to?(:embedding_b64) && job.embedding_b64 && !job.embedding_b64.to_s.empty?
                session[:research_interest_embedding_b64] = job.embedding_b64
              else
                session.delete(:research_interest_embedding_b64)
              end

              concepts =
                begin
                  JSON.parse(job.concepts_json.to_s)
                rescue StandardError => e
                  AcaRadar.logger.error("SPECIAL DEBUG: Concepts parse error on polling completion: #{e.message}")
                  []
                end
                AcaRadar.logger.info("SPECIAL DEBUG: RI Job Completed. ID: #{job_id}, Concepts: #{concepts.inspect}")

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

            request_id = session[:research_interest_request_id]
            AcaRadar.logger.debug(
              "PAPERS start journals=#{request_obj.journals.inspect} page=#{request_obj.page} " \
              "request_id=#{request_id.inspect} term=#{session[:research_interest_term].inspect}"
            )

            AcaRadar.logger.info("SPECIAL DEBUG: Papers request received. Request ID from session: #{request_id}")

            research_embedding = nil

            if request_id
              job = Repository::ResearchInterestJob.find(request_id)

              if job
                AcaRadar.logger.debug(
                  "PAPERS job found job_id=#{job.job_id} status=#{job.status.inspect} " \
                  "has_embedding_b64=#{job.respond_to?(:embedding_b64) && !job.embedding_b64.to_s.empty?}"
                )

                if job.status == 'completed'
                  b64 =
                    if job.respond_to?(:embedding_b64) && job.embedding_b64 && !job.embedding_b64.to_s.empty?
                      job.embedding_b64
                    else
                      session[:research_interest_embedding_b64]
                    end

                  if b64 && !b64.to_s.empty?
                    begin
                      research_embedding = Base64.decode64(b64).unpack('e*') # float32 LE
                      AcaRadar.logger.debug("PAPERS decoded RI embedding len=#{research_embedding.length} b64_bytes=#{b64.bytesize}")
                    rescue StandardError => e
                      AcaRadar.logger.error("PAPERS RI embedding decode failed: #{e.class} - #{e.message}")
                      research_embedding = nil
                    end
                  else
                    AcaRadar.logger.debug("PAPERS completed job but no embedding available; similarity disabled")
                  end
                else
                  AcaRadar.logger.debug("PAPERS job not completed yet; similarity disabled")
                end
              else
                AcaRadar.logger.debug("PAPERS no job record found for request_id=#{request_id}; similarity disabled")
              end
            else
              AcaRadar.logger.debug('PAPERS no request_id in session; similarity disabled')
            end

            result = Service::ListPapers.new.call(
              journals: request_obj.journals,
              page: request_obj.page,
              research_embedding: research_embedding
            )
            standard_response(:internal_error, 'Failed to list papers') if result.failure?

            list = result.value!

            begin
              top5 = Array(list.papers).first(5).map { |p| [p.title, p.similarity_score] }
              AcaRadar.logger.debug("PAPERS returned top5 (title, similarity_score): #{top5.inspect}")
            rescue StandardError => e
              AcaRadar.logger.warn("PAPERS top5 debug failed: #{e.class} - #{e.message}")
            end

            cache_ttl = 300
            cache_key = [
              request_obj.journals.sort.join(','),
              request_obj.page,
              request_id.to_s
            ].join('|')
            etag_value = Digest::SHA256.hexdigest(cache_key)

            response['Cache-Control'] = "private, max-age=#{cache_ttl}"
            response['Vary']          = 'Cookie'
            response['ETag']          = %("#{etag_value}")

            standard_response(:not_modified, 'Not Modified') if env['HTTP_IF_NONE_MATCH'] == %("#{etag_value}")

            response_obj = OpenStruct.new(
              research_interest_term: session[:research_interest_term],
              research_interest_2d:   session[:research_interest_2d],
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

    def standard_response(status_sym, message, data = nil)
      response_wrapper = Response::HttpResponse.new(
        status: status_sym,
        message: message,
        data: data
      )

      response.status = response_wrapper.code
      request.halt response.status, response_wrapper.to_json
    end

    def normalize_term(term)
      term.to_s.strip.downcase.gsub(/\s+/, ' ')
    end

    # Uses the DB as the local cache
    # Requires jobs table to store completed embeddings (embedding_b64 / embedding_dim).
    def find_cached_completed_job_by_term(normalized_term)
      return nil if normalized_term.empty?

      return nil unless defined?(AcaRadar::Database::ResearchInterestJobOrm)

      AcaRadar::Database::ResearchInterestJobOrm
        .where(status: 'completed')
        .where(Sequel.function(:lower, :term) => normalized_term)
        .order(Sequel.desc(:updated_at))
        .first
    rescue StandardError => e
      AcaRadar.logger.warn("RI cache lookup failed term=#{normalized_term.inspect}: #{e.class} - #{e.message}")
      nil
    end
  end
end
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/BlockLength
