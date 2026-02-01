# frozen_string_literal: true

require 'json'
require 'http'
require_relative '../../../infrastructure/utilities/logger'

module Sparko
  module Value
    class Embedding
      attr_reader :full_embedding, :short_embedding

      def initialize(embedding)
        @full_embedding = Array(embedding).compact.map(&:to_f)
        @short_embedding = truncate_to_10_dims(@full_embedding)
      end

      def self.embed_from(concept)
        input = concept.to_s
        url   = ENV.fetch('EMBED_SERVICE_URL', 'http://localhost:8001/embed')

        # Use request id if you have one; otherwise generate cheap trace id
        trace_id = ENV['ACARADAR_TRACE_ID'] || "ri-#{Time.now.to_i}-#{rand(1000)}"

        Sparko.logger.debug("EMBED HTTP start url=#{url} text_len=#{input.length} trace_id=#{trace_id}")

        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = HTTP
                   .headers(
                     content_type: 'application/json',
                     accept: 'application/json',
                     'X-Request-Id' => trace_id
                   )
                   .timeout(connect: 2, read: 30)
                   .post(url, json: { text: input })

        ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
        Sparko.logger.debug("EMBED HTTP resp code=#{response.code} ms=#{ms.round(1)} trace_id=#{trace_id}")

        unless response.code.between?(200, 299)
          body = response.body.to_s
          Sparko.logger.error("EMBED HTTP error code=#{response.code} body=#{body[0, 300]}")
          raise "Embed service failed: #{response.code}"
        end

        parsed = JSON.parse(response.body.to_s)
        embedding = parsed['embedding'] || []
        service_ms = parsed['ms']

        Sparko.logger.debug("EMBED parsed emb_dim=#{embedding.length} service_ms=#{service_ms.inspect} trace_id=#{trace_id}")

        new(embedding)
      rescue JSON::ParserError => e
        raise "Failed to parse JSON from embed service: #{e.message}"
      rescue HTTP::TimeoutError
        Sparko.logger.error('EMBED HTTP timeout')
        raise 'Embed service timed out'
      end

      private

      def truncate_to_10_dims(embedding_vector)
        embedding_vector.length > 10 ? embedding_vector.first(10) : embedding_vector
      end
    end
  end
end
