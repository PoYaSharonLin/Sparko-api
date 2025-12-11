# frozen_string_literal: true

require_relative '../representers/http_response'
require 'json'

module AcaRadar
  module Response
    # Standard response wrapper for all API endpoints
    class HttpResponse
      attr_reader :status, :message, :data

      def initialize(status:, message:, data: nil)
        @status = status
        @message = message
        @data = data
      end

      # Maps symbols to HTTP status codes
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/MethodLength
      def code
        case status
        when :ok, :success        then 200
        when :created             then 201
        when :processing          then 202
        when :no_content          then 204
        when :not_modified        then 304
        when :bad_request         then 400
        when :unauthorized        then 401
        when :forbidden           then 403
        when :not_found           then 404
        when :conflict            then 409
        when :cannot_process      then 422
        when :internal_error      then 500
        else 418 # block automatic traffic and this server is a teapot
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength

      def to_json(*_args)
        Representer::HttpResponse.new(self).to_json
      end
    end
  end
end
