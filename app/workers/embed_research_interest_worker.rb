# frozen_string_literal: true

require 'shoryuken'
require 'json'
require 'base64'
require 'logger'

module AcaRadar
  module Workers
    class EmbedResearchInterestWorker
      include Shoryuken::Worker

      shoryuken_options queue: ENV.fetch('SQS_QUEUE_NAME', 'acaradar-research-interest-dev'),
                        auto_delete: true

      LOGGER = Logger.new($stdout)

      def perform(_sqs_msg, body)
        sent_at = Time.at(_sqs_msg.attributes['SentTimestamp'].to_i / 1000.0)
        delay = Time.now - sent_at
        LOGGER.debug("WORKER received message. SQS Delay: #{delay.round(2)}s")

        payload = parse_body(body)
        return unless payload['type'] == 'embed_research_interest'

        job_id = payload['job_id']
        term   = payload['term']

        LOGGER.debug("WORKER start job_id=#{job_id} term=#{term.inspect}")
        LOGGER.debug("WORKER env TRANSFORMERS_CACHE=#{ENV['TRANSFORMERS_CACHE'].inspect} HF_HOME=#{ENV['HF_HOME'].inspect}")

        #this is a safeguard so we don't get two shoryuken workers doing the same job
        claimed = AcaRadar::Repository::ResearchInterestJob.try_mark_processing(job_id)

        unless claimed
          LOGGER.info("WORKER skip job_id=#{job_id} (already processing/completed/failed)")
          return
        end

        result = Service::EmbedResearchInterest.new.call(term: term, request_id: job_id)

        if result.failure?
          LOGGER.error("WORKER failed job_id=#{job_id} error=#{result.failure}")
          AcaRadar::Repository::ResearchInterestJob.mark_failed(job_id, result.failure)
          return
        end

        payload_hash = result.value!
        vector_2d    = payload_hash[:vector_2d] || payload_hash['vector_2d']
        embedding    = payload_hash[:embedding] || payload_hash['embedding']
        concepts     = payload_hash[:concepts] || payload_hash['concepts']

        vector_2d =
          if vector_2d.is_a?(Hash)
            x = vector_2d['x'] || vector_2d[:x]
            y = vector_2d['y'] || vector_2d[:y]
            [x.to_f, y.to_f]
          elsif vector_2d.is_a?(Array) && vector_2d.size >= 2
            [vector_2d[0].to_f, vector_2d[1].to_f]
          end

        unless vector_2d.is_a?(Array) && vector_2d.size == 2
            LOGGER.error("WORKER invalid vector_2d job_id=#{job_id} vec=#{vector_2d.inspect}")
            AcaRadar::Repository::ResearchInterestJob.mark_failed(job_id, "Invalid vector_2d")
            return
        end
          
        embedding_b64 = nil
        embedding_dim = nil

        if embedding.is_a?(Array) && !embedding.empty?
          floats = embedding.map(&:to_f)
          packed = floats.pack('e*')
          embedding_b64 = Base64.strict_encode64(packed)
          embedding_dim = floats.length
        end

        LOGGER.debug(
          "WORKER completed job_id=#{job_id} vec2d=#{vector_2d.inspect} " \
          "emb_dim=#{embedding_dim.inspect} b64_bytes=#{embedding_b64&.bytesize}"
        )

        AcaRadar::Repository::ResearchInterestJob.mark_completed(
          job_id,
          vector_2d,
          embedding_b64: embedding_b64,
          embedding_dim: embedding_dim,
          concepts: concepts
        )
      rescue StandardError => e
        LOGGER.error("WORKER exception job_id=#{job_id}: #{e.class} - #{e.message}")
        LOGGER.error(e.backtrace&.first(10)&.join("\n"))
        AcaRadar::Repository::ResearchInterestJob.mark_failed(job_id, e) if job_id
      end

      private

      def parse_body(body)
        body.is_a?(String) ? JSON.parse(body) : body
      end
    end
  end
end
