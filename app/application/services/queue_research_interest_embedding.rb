# frozen_string_literal: true

require 'dry/monads'
require 'securerandom'
require_relative '../../infrastructure/utilities/logger'

module Sparko
  module Service
    class QueueResearchInterestEmbedding
      include Dry::Monads[:result]

      CACHE_MAX_AGE = 7 * 24 * 60 * 60 # 7 days (tweak or set nil to never expire)

      def call(term:)
        normalized = normalize_term(term)

        # 1) CACHE HIT: reuse existing completed job
        cached = Repository::ResearchInterestJob.find_completed_by_term(
          normalized,
          max_age_seconds: CACHE_MAX_AGE
        )

        if cached
          Sparko.logger.debug(
            "RI cache hit term=#{normalized.inspect} job_id=#{cached.job_id}"
          )
          return Success(cached.job_id)
        end

        # 2) CACHE MISS: create + enqueue
        job_id = SecureRandom.uuid

        Repository::ResearchInterestJob.create(job_id: job_id, term: normalized)

        Messaging::SqsClient.publish(
          type: 'embed_research_interest',
          job_id: job_id,
          term: normalized
        )

        Success(job_id)
      rescue StandardError => e
        Sparko.logger.error("Failed to queue embed job: #{e.class} - #{e.message}")
        Failure('Failed to queue embedding job')
      end

      private

      def normalize_term(t)
        t.to_s.strip.downcase.gsub(/\s+/, ' ')
      end
    end
  end
end
