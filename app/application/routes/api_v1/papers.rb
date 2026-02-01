# frozen_string_literal: true

require 'digest'
require 'base64'
require 'ostruct'

module Sparko
  module Routes
    # Papers routes - /api/v1/papers
    module Papers
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def handle_papers_route(routing)
        routing.on 'papers' do
          routing.get do
            request_obj = Request::ListPapers.new(routing.params)

            unless request_obj.valid?
              standard_response(:bad_request, request_obj.error_message || 'Invalid request')
            end

            request_id =
              routing.params['request_id'] ||
              routing.params['job_id'] ||
              session[:research_interest_request_id]

            job = request_id ? Repository::ResearchInterestJob.find(request_id) : nil

            Sparko.logger.debug(
              "PAPERS start journals=#{request_obj.journals.inspect} page=#{request_obj.page} " \
              "request_id=#{request_id.inspect} job_status=#{job&.status.inspect} term=#{job&.term.inspect}"
            )

            # If the caller provided a request_id, require that job to be completed
            if request_id && (!job || job.status != 'completed')
              data = {
                status: job&.status || 'queued',
                request_id: request_id,
                status_url: "/api/v1/research_interest/#{request_id}"
              }
              standard_response(:processing, 'Research interest still processing', data)
            end

            research_embedding = extract_research_embedding(job)
            top_n_raw = routing.params['top_n'] || routing.params['n']

            # If the client requests top_n, require an embedded research interest
            if top_n_raw && !top_n_raw.to_s.strip.empty? && !research_embedding.is_a?(Array)
              standard_response(:bad_request, 'top_n requires an embedded research interest (request_id)')
            end

            result = Service::ListPapers.new.call(
              journals: request_obj.journals,
              page: request_obj.page,
              research_embedding: research_embedding,
              top_n: top_n_raw,
              min_date: request_obj.min_date,
              max_date: request_obj.max_date
            )

            standard_response(:internal_error, 'Failed to list papers') if result.failure?

            list = result.value!
            log_top_papers(list)

            # HTTP caching
            cache_ttl = 300
            cache_key = [
              request_obj.journals.sort.join(','),
              request_obj.page,
              request_id.to_s
            ].join('|')
            etag_value = Digest::SHA256.hexdigest(cache_key)

            response['Cache-Control'] = "private, max-age=#{cache_ttl}"
            response['Vary'] = 'Cookie'
            response['ETag'] = %("#{etag_value}")

            standard_response(:not_modified, 'Not Modified') if env['HTTP_IF_NONE_MATCH'] == %("#{etag_value}")

            ri_term = job&.term || session[:research_interest_term]
            ri_2d = if job && job.status == 'completed'
                      [job.vector_x.to_f, job.vector_y.to_f]
                    else
                      session[:research_interest_2d]
                    end

            response_obj = OpenStruct.new(
              research_interest_term: ri_term,
              research_interest_2d: ri_2d,
              journals: request_obj.journals,
              papers: list
            )
            data = Representer::PapersPageResponse.new(response_obj)

            standard_response(:ok, 'Papers retrieved successfully', data)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      private

      def extract_research_embedding(job)
        return nil unless job

        b64 = if job.respond_to?(:embedding_b64) && job.embedding_b64 && !job.embedding_b64.to_s.empty?
                job.embedding_b64
              else
                session[:research_interest_embedding_b64]
              end

        return nil unless b64 && !b64.to_s.empty?

        Base64.decode64(b64).unpack('e*') # float32 LE
      rescue StandardError => e
        Sparko.logger.error("PAPERS RI embedding decode failed: #{e.class} - #{e.message}")
        nil
      end

      def log_top_papers(list)
        top5 = Array(list.papers).first(5).map { |p| [p.title, p.similarity_score] }
        Sparko.logger.debug("PAPERS returned top5 (title, similarity_score): #{top5.inspect}")
      rescue StandardError => e
        Sparko.logger.warn("PAPERS top5 debug failed: #{e.class} - #{e.message}")
      end
    end
  end
end
