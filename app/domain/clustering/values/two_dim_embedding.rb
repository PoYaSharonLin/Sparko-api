# frozen_string_literal: true

require 'open3'
require 'json'

# rubocop:disable Metrics/MethodLength
module AcaRadar
  module Value
    # class for two dim embedding
    class TwoDimEmbedding
      attr_reader :two_dim_embedding

      def initialize(two_dim_embedding)
        @two_dim_embedding = two_dim_embedding
      end

      def to_s
        @two_dim_embedding.to_s
      end

      def self.reduce_dimension_from(embedding)
        input = embedding.to_json
        dim_reducer_path = ENV['DIM_REDUCER_PATH'] || 'app/domain/clustering/services/dimension_reducer.py'

        mean_path = ENV['PCA_MEAN_PATH'] || 'app/domain/clustering/services/pca_mean.json'
        comp_path = ENV['PCA_COMPONENTS_PATH'] || 'app/domain/clustering/services/pca_components.json'

        stdout, stderr, status = Open3.capture3(
          { 'PCA_MEAN_PATH' => mean_path, 'PCA_COMPONENTS_PATH' => comp_path },
          'python3', dim_reducer_path,
          '--mean-path', mean_path,
          '--components-path', comp_path,
          stdin_data: input
        )

        raise "Python dimension_reducer.py failed: #{stderr}" unless status.success?

        parsed_json = JSON.parse(stdout)
        new(parsed_json)
      rescue JSON::ParserError => e
        raise "Failed to parse JSON from dimension_reducer.py: #{e.message}"
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
