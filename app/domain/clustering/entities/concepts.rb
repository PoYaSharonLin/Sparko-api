# frozen_string_literal: true

require 'open3'
require 'json'

module AcaRadar
  # Domain entity module
  module Entity
    # Represents the concept extracted from summary
    class Concept
      def initialize(concept)
        @concept = concept.to_s
      end

      def to_s
        @concept
      end

      # rubocop:disable Metrics/MethodLength
      def self.extract_from(summary)
        input = summary.to_s
        extractor_path = ENV['EXTRACTOR_PATH'] || 'app/domain/clustering/services/extractor.py'

        stdout, stderr, status = Open3.capture3('python3', extractor_path, stdin_data: input)

        raise "Python script failed: #{stderr}" unless status.success?

        begin
          parsed_json = JSON.parse(stdout)
          parsed_json.map do |concept_data|
            new(concept_data)
          end
        rescue JSON::ParserError => e
          raise "Failed to parse JSON from extractor.py: #{e.message}"
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
