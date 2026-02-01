# frozen_string_literal: true

require "aws-sdk-sqs"
require "aws-sdk-sts"
require "json"

module Sparko
  module Messaging
    class SqsClient
      class << self
        def client
          @client ||= Aws::SQS::Client.new(
            region: ENV.fetch("AWS_REGION", "us-east-1"),
            retry_mode: (ENV["AWS_RETRY_MODE"] || "adaptive"),
            max_attempts: Integer(ENV["AWS_MAX_ATTEMPTS"] || "10"),

            # laptop-friendly timeouts
            http_open_timeout: Float(ENV["AWS_HTTP_OPEN_TIMEOUT"] || "2"),
            http_read_timeout: Float(ENV["AWS_HTTP_READ_TIMEOUT"] || "15"),
            http_idle_timeout: Float(ENV["AWS_HTTP_IDLE_TIMEOUT"] || "5")
          )
        end

        def queue_url
          @queue_url ||= ENV.fetch("SQS_QUEUE_URL")
        end

        # Only call STS when explicitly enabled (STS calls add latency + noise)
        def log_identity_if_enabled!
          return unless ENV["LOG_AWS_IDENTITY_ON_PUBLISH"] == "1"

          ident = Aws::STS::Client.new(region: ENV.fetch("AWS_REGION", "us-east-1")).get_caller_identity
          Sparko.logger.info(
            "AWS identity account=#{ident.account} arn=#{ident.arn} region=#{ENV.fetch('AWS_REGION', 'us-east-1')}"
          )
        rescue StandardError => e
          Sparko.logger.warn("AWS identity lookup failed: #{e.class} #{e.message}")
        end

        def publish(message_hash)
          log_identity_if_enabled!

          msg = message_hash.is_a?(Hash) ? message_hash.dup : { "payload" => message_hash }
          msg["client_enqueued_at_ms"] ||= (Time.now.to_f * 1000).to_i #for debugging

          resp = client.send_message(
            queue_url: queue_url,
            message_body: JSON.generate(msg)
          )

          Sparko.logger.debug("SQS sent message_id=#{resp.message_id} queue=#{queue_url}")
          resp
        end
      end
    end
  end
end
