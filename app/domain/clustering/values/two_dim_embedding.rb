# frozen_string_literal: true

require 'open3'
require 'json'

module AcaRadar
  # Value objects depending on Domain Entity
  module Value
    # Represents 2Dembedding reduced from embedding objects
    class TwoDimEmbedding
      attr_reader :two_dim_embedding

      def initialize(two_dim_embedding)
        @two_dim_embedding = two_dim_embedding
      end

      def self.reduce_dimension_from(embedding)
        input = embedding
        embedder_path = ENV['EMBEDDER_PATH'] || 'app/domain/clustering/services/embedder.py'

        stdout, stderr, status = Open3.capture3('python3', embedder_path, stdin_data: input)

        raise "Python script failed: #{stderr}" unless status.success?

        begin
          parsed_json = JSON.parse(stdout)
          new(parsed_json)
        rescue JSON::ParserError => e
          raise "Failed to parse JSON from embedder.py: #{e.message}"
        end
      end
    end
  end
end
