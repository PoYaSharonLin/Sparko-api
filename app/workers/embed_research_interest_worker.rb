# frozen_string_literal: true

require 'shoryuken'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
module AcaRadar
  module Workers
    # class for embed research interest worker
    class EmbedResearchInterestWorker
      include Shoryuken::Worker

      # Queue name from env so we can have dev/test queues
      shoryuken_options queue: ENV.fetch('SQS_QUEUE_NAME', 'acaradar-research-interest-dev'),
                        auto_delete: true

      def perform(_sqs_msg, body)
        payload = parse_body(body)

        return unless payload['type'] == 'embed_research_interest'

        job_id = payload['job_id']
        term   = payload['term']

        Repository::ResearchInterestJob.mark_processing(job_id)

        result = Service::EmbedResearchInterest.new.call(term: term)

        if result.failure?
          Repository::ResearchInterestJob.mark_failed(job_id, result.failure)
        else
          vector_2d = result.value!
          Repository::ResearchInterestJob.mark_completed(job_id, vector_2d)
        end
      rescue StandardError => e
        Repository::ResearchInterestJob.mark_failed(job_id, e) if job_id
        AcaRadar::App::APP_LOGGER.error(
          "EmbedResearchInterestWorker failed: #{e.class} - #{e.message}"
        )
      end

      private

      def parse_body(body)
        body.is_a?(String) ? JSON.parse(body) : body
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
