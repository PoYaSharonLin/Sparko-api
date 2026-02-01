# frozen_string_literal: true

module Sparko
  # Holds the primary and weird secondary categories of the paper
  module Entity
    # Represents categories, should have names defined by arxiv and commonly understandable names
    class Categories
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
