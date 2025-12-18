# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
module AcaRadar
  module Service
    # class to calculate cosine similarity
    class CalculateSimilarity
      def self.score(vector_a, vector_b)
        return 0.0 unless valid_vectors?(vector_a, vector_b)

        dot = 0.0
        norm_a = 0.0
        norm_b = 0.0

        vector_a.each_with_index do |a, i|
          b = vector_b[i]
          a = a.to_f
          b = b.to_f

          dot += a * b
          norm_a += a * a
          norm_b += b * b
        end

        denom = Math.sqrt(norm_a) * Math.sqrt(norm_b)
        return 0.0 if denom.zero?

        dot / denom
      end

      def self.valid_vectors?(vec_a, vec_b)
        vec_a.is_a?(Array) && vec_b.is_a?(Array) && !vec_a.empty? && vec_a.size == vec_b.size
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/AbcSize
