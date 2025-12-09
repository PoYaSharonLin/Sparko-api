# frozen_string_literal: true

require 'dry/monads'
require 'securerandom'

# rubocop:disable Metrics/MethodLength
module AcaRadar
  module Service
    # class for service queues for research interest
    class QueueResearchInterestEmbedding
      include Dry::Monads[:result]

      def call(term:)
        job_id = SecureRandom.uuid

        Repository::ResearchInterestJob.create(job_id: job_id, term: term)

        Messaging::SqsClient.publish(
          type: 'embed_research_interest',
          job_id: job_id,
          term: term
        )

        Success(job_id)
      rescue StandardError => e
        AcaRadar::App::APP_LOGGER.error("Failed to queue embed job: #{e.class} - #{e.message}")
        Failure('Failed to queue embedding job')
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
