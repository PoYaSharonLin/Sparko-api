# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'json'

module AcaRadar
  module Messaging
    # class for sqs clients
    class SqsClient
      def self.client
        @client ||= Aws::SQS::Client.new(
          region: ENV.fetch('AWS_REGION', 'us-east-1')
        )
      end

      def self.queue_url
        @queue_url ||= ENV.fetch('SQS_QUEUE_URL')
      end

      def self.publish(message_hash)
        resp = client.send_message(
          queue_url: queue_url,
          message_body: JSON.generate(message_hash)
        )
        AcaRadar.logger.debug("SQS sent message_id=#{resp.message_id} queue=#{queue_url}")
        resp
      end
    end
  end
end
