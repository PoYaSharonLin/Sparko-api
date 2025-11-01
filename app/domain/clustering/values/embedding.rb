# frozen_string_literal: true

require 'open3'
require 'json'

module AcaRadar
  # Value objects depending on Domain Entity
  module Value
    # Represents embedding of the concepts
    class Embedding
      attr_reader :full_embedding, :short_embedding

      def initialize(embedding)
        @full_embedding = Array(embedding).compact.map(&:to_f)
        @short_embedding = truncate_to_10_dims(@full_embedding)
      end

      def self.embed_from(concept)
        input = concept.to_s
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

      private

      def truncate_to_10_dims(embedding_vector)
        if embedding_vector.length > 10
          embedding_vector.first(10)
        else
          embedding_vector
        end
      end
    end
  end
end
