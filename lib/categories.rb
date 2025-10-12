# frozen_string_literal: true

module AcaRadar
  # Holds the primary and weird secondary categories of the paper
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
