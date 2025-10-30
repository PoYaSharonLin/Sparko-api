# frozen_string_literal: true

module AcaRadar
  # Value objects depending on Domain Entity
  module Value
    # Represents summary of the paper
    class Embeddings
      attr_reader :all, :primary

      def initialize(categories, primary_category)
        @all     = Array(categories).compact.uniq
        @primary = primary_category
      end

      def to_h
        {
          primary_category: primary,
          categories: all
        }.compact
      end
    end
  end
end
