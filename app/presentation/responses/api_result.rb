# frozen_string_literal: true

require_relative '../representers/http_response'
require 'json'

module AcaRadar
  module Response
    # class that represents the http status code and message
    class ApiResult
      attr_reader :status, :message

      def initialize(status:, message:)
        @status = status
        @message = message
      end

      def http_status_code
        case status
        when :ok        then 200
        when :created   then 201
        when :bad_request then 400
        when :unprocessable then 422
        when :not_found then 404
        else 202
        end
      end

      def to_json(*_args)
        Representer::HttpResponse.new(self).to_json
      end
    end
  end
end
