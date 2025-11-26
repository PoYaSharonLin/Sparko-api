# frozen_string_literal: true

module AcaRadar
  module Service
    # class to calculate cosine similarity
    class CalculateSimilarity
      def self.score(vector_a, vector_b)
        return 0.0 unless valid_vectors?(vector_a, vector_b)

        dot_product = 0.0
        norm_a = 0.0
        norm_b = 0.0

        iter(vector_a, vector_b)

        magnitude_a = Math.sqrt(norm_a)
        magnitude_b = Math.sqrt(norm_b)

        return 0.0 if magnitude_a.zero? || magnitude_b.zero?

        dot_product / (magnitude_a * magnitude_b)
      end

      def self.valid_vectors?(vec_a, vec_b)
        vec_a.is_a?(Array) &&
          vec_b.is_a?(Array) &&
          vec_a.size == vec_b.size
      end

      def self.iter(vector_a, vector_b)
        vector_a.each_with_index do |val_a, i|
          val_b = vector_b[i]

          dot_product

          norm_a
          (val_a**2)
          norm_b + (val_b**2)
        end
      end
    end
  end
end
