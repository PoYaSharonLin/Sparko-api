# frozen_string_literal: true

require 'http'
require 'json'
require_relative '../utilities/logger'

# rubocop:disable Metrics/MethodLength
module Sparko
  module Messaging
    # Publishes progress updates to a Faye channel
    class Publisher
      def initialize(config, request_id)
        @config = config
        @channel_id = "/#{request_id}"
      end

      # @param [String] status - e.g., 'processing', 'failed', 'completed'
      # @param [String] message - e.g., 'Embedding research interest...'
      # @param [Integer] percent - e.g., 25, 50, 100
      def publish(status:, message:, percent: nil, payload: {})
        @api_host = ENV.fetch('API_HOST')
        faye_url = "#{@api_host}/faye"

        data = {
          status: status,
          message: message,
          percent: percent
        }.merge(payload)

        faye_message = {
          channel: @channel_id,
          data: data
        }.to_json

        Sparko.logger.debug("FAYE_PUBLISH: Posting to #{faye_url} on channel #{@channel_id}")

        HTTP.post(faye_url, form: { message: faye_message })
      rescue HTTP::ConnectionError => e
        Sparko.logger.error("FAYE_ERROR: Server not found at #{faye_url}. Details: #{e.message}")
      rescue StandardError => e
        Sparko.logger.error("FAYE_ERROR: Generic failure. Details: #{e.message}")
      end

      private

      def message_body(data)
        {
          channel: @channel_id,
          data: data
        }.to_json
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
