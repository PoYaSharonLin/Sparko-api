# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'json'

module AcaRadar
  module Messaging
    # class for sqs clients
    class SqsClient
      def self.client
        @client ||= Aws::SQS::Client.new(
          region: ENV.fetch('AWS_REGION', 'eu-west-1')
          # credentials from ENV: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
        )
      end

      def self.queue_url
        @queue_url ||= ENV.fetch('SQS_QUEUE_URL')
      end

      def self.publish(message_hash)
        client.send_message(
          queue_url: queue_url,
          message_body: JSON.generate(message_hash)
        )
      end
    end
  end
end

# export AWS_REGION=eu-west-1
# export SQS_QUEUE_URL="https://sqs.eu-west-1.amazonaws.com/<acct>/acaradar-research-interest-dev"
