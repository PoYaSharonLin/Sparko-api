# frozen_string_literal: true

require "shoryuken"
require "json"
require "base64"

module Sparko
  module Workers
    class EmbedResearchInterestWorker
      include Shoryuken::Worker

      shoryuken_options(
        queue: ENV.fetch("SQS_QUEUE_NAME", "sparko-research-interest-dev"),
        auto_delete: true
      )

      def embed_endpoint
        raw = ENV["EMBED_SERVICE_URL"].to_s.strip
        raw = "http://localhost:8001/embed" if raw.empty?
        raw.end_with?("/embed") ? raw : "#{raw.sub(%r{/\z}, "")}/embed"
      end

      def perform(sqs_msg, body)
        # ---- SQS metadata (useful for "stall" diagnosis) ----
        msg_id = (sqs_msg.message_id rescue nil)

        sent_ms = (sqs_msg.attributes["SentTimestamp"].to_i rescue 0)
        first_recv_ms = (sqs_msg.attributes["ApproximateFirstReceiveTimestamp"].to_i rescue 0)
        recv_count = (sqs_msg.attributes["ApproximateReceiveCount"].to_i rescue 0)
        now_ms = (Time.now.to_f * 1000).to_i

        sqs_delay_s = sent_ms > 0 ? ((now_ms - sent_ms) / 1000.0) : nil
        first_recv_age_s = first_recv_ms > 0 ? ((now_ms - first_recv_ms) / 1000.0) : nil

        Sparko.logger.debug(
          "WORKER received message_id=#{msg_id} recv_count=#{recv_count} " \
          "sqs_delay_s=#{sqs_delay_s&.round(2)} first_recv_age_s=#{first_recv_age_s&.round(2)}"
        )

        payload = parse_body(body)
        return unless payload["type"] == "embed_research_interest"

        job_id = payload["job_id"]
        term   = payload["term"]

        Sparko.logger.debug("WORKER start job_id=#{job_id} term=#{term.inspect}")
        Sparko.logger.debug(
          "WORKER env TRANSFORMERS_CACHE=#{ENV['TRANSFORMERS_CACHE'].inspect} HF_HOME=#{ENV['HF_HOME'].inspect}"
        )

        # safeguard so two workers don't do the same job
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        claimed = Sparko::Repository::ResearchInterestJob.try_mark_processing(job_id)
        t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Sparko.logger.debug(
          "DB try_mark_processing took #{((t1 - t0) * 1000).round(1)}ms job_id=#{job_id} claimed=#{claimed}"
        )

        unless claimed
          Sparko.logger.info("WORKER skip job_id=#{job_id} (already processing/completed/failed)")
          return
        end

        # Ensure your embed client hits the right endpoint even if ENV is base URL
        # (You likely have Service::EmbedResearchInterest using ENV['EMBED_SERVICE_URL'])
        ENV["EMBED_SERVICE_URL"] = embed_endpoint

        result = Service::EmbedResearchInterest.new.call(term: term, request_id: job_id)

        if result.failure?
          Sparko.logger.error("WORKER failed job_id=#{job_id} error=#{result.failure}")
          Sparko::Repository::ResearchInterestJob.mark_failed(job_id, result.failure)
          return
        end

        payload_hash = result.value!
        vector_2d    = payload_hash[:vector_2d] || payload_hash["vector_2d"]
        embedding    = payload_hash[:embedding] || payload_hash["embedding"]
        concepts     = payload_hash[:concepts] || payload_hash["concepts"]

        vector_2d =
          if vector_2d.is_a?(Hash)
            x = vector_2d["x"] || vector_2d[:x]
            y = vector_2d["y"] || vector_2d[:y]
            [x.to_f, y.to_f]
          elsif vector_2d.is_a?(Array) && vector_2d.size >= 2
            [vector_2d[0].to_f, vector_2d[1].to_f]
          end

        unless vector_2d.is_a?(Array) && vector_2d.size == 2
          Sparko.logger.error("WORKER invalid vector_2d job_id=#{job_id} vec=#{vector_2d.inspect}")
          Sparko::Repository::ResearchInterestJob.mark_failed(job_id, "Invalid vector_2d")
          return
        end

        embedding_b64 = nil
        embedding_dim = nil

        if embedding.is_a?(Array) && !embedding.empty?
          floats = embedding.map(&:to_f)
          packed = floats.pack("e*") # float32 little-endian
          embedding_b64 = Base64.strict_encode64(packed)
          embedding_dim = floats.length
        end

        Sparko.logger.debug(
          "WORKER completed job_id=#{job_id} vec2d=#{vector_2d.inspect} " \
          "emb_dim=#{embedding_dim.inspect} b64_bytes=#{embedding_b64&.bytesize}"
        )

        Sparko::Repository::ResearchInterestJob.mark_completed(
          job_id,
          vector_2d,
          embedding_b64: embedding_b64,
          embedding_dim: embedding_dim,
          concepts: concepts
        )
      rescue StandardError => e
        Sparko.logger.error("WORKER exception job_id=#{job_id}: #{e.class} - #{e.message}")
        Sparko.logger.error(e.backtrace&.first(10)&.join("\n"))
        Sparko::Repository::ResearchInterestJob.mark_failed(job_id, e) if defined?(job_id) && job_id
      end

      private

      def parse_body(body)
        body.is_a?(String) ? JSON.parse(body) : body
      end
    end
  end
end
