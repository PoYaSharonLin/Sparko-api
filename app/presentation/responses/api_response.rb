# frozen_string_literal: true

require 'json'
require 'time'

module Sparko
  module Response
    # iOS-friendly API response wrapper
    #
    # Provides a standardized JSON envelope optimized for iOS clients:
    # - Consistent structure: { status, code, message, data, meta }
    # - ISO 8601 timestamps for Swift Codable
    # - snake_case keys (works with Swift's keyDecodingStrategy)
    # - Helper methods for caching headers
    #
    # @example Basic usage
    #   ApiResponse.ok('Success', { user: { name: 'John' } })
    #
    # @example With meta information
    #   ApiResponse.ok('Papers retrieved', papers, meta: { page: 1, total: 100 })
    class ApiResponse
      attr_reader :status, :message, :data, :meta

      # Factory methods for common responses
      class << self
        def ok(message, data = nil, meta: nil)
          new(status: :ok, message: message, data: data, meta: meta)
        end

        def created(message, data = nil, meta: nil)
          new(status: :created, message: message, data: data, meta: meta)
        end

        def processing(message, data = nil, meta: nil)
          new(status: :processing, message: message, data: data, meta: meta)
        end

        def bad_request(message, data = nil)
          new(status: :bad_request, message: message, data: data)
        end

        def not_found(message, data = nil)
          new(status: :not_found, message: message, data: data)
        end

        def error(message, data = nil)
          new(status: :internal_error, message: message, data: data)
        end
      end

      def initialize(status:, message:, data: nil, meta: nil)
        @status = status
        @message = message
        @data = data
        @meta = build_meta(meta)
      end

      # HTTP status code
      def code
        STATUS_CODES.fetch(status, 418)
      end

      # JSON serialization for iOS clients
      def to_json(*_args)
        {
          status: status.to_s,
          code: code,
          message: message,
          data: serialize_data(data),
          meta: meta
        }.compact.to_json
      end

      # Generate ETag for caching
      def etag(content = nil)
        content ||= [status, message, data].map(&:to_s).join('|')
        Digest::SHA256.hexdigest(content)
      end

      # Apply iOS-friendly cache headers to response
      def apply_cache_headers(response, max_age: 60, private_cache: true)
        cache_type = private_cache ? 'private' : 'public'
        response['Cache-Control'] = "#{cache_type}, max-age=#{max_age}"
        response['Vary'] = 'Accept, Accept-Encoding'
        response['ETag'] = %("#{etag}")
      end

      private

      STATUS_CODES = {
        ok: 200,
        success: 200,
        created: 201,
        processing: 202,
        no_content: 204,
        not_modified: 304,
        bad_request: 400,
        unauthorized: 401,
        forbidden: 403,
        not_found: 404,
        conflict: 409,
        cannot_process: 422,
        internal_error: 500
      }.freeze

      def build_meta(custom_meta)
        base = { timestamp: Time.now.utc.iso8601 }
        custom_meta ? base.merge(custom_meta) : base
      end

      # Recursively serialize data, converting dates to ISO 8601
      def serialize_data(obj)
        case obj
        when Time, DateTime
          obj.to_time.utc.iso8601
        when Date
          obj.iso8601
        when Hash
          obj.transform_values { |v| serialize_data(v) }
        when Array
          obj.map { |v| serialize_data(v) }
        when ->(o) { o.respond_to?(:to_hash) }
          serialize_data(obj.to_hash)
        when ->(o) { o.respond_to?(:to_h) }
          serialize_data(obj.to_h)
        else
          obj
        end
      end
    end
  end
end
