# frozen_string_literal: true

module AcaRadar
  # Library for Category object
  class Category
    def initialize(category_data)
      # hot fix: only return the first hash
      @category = category_data.is_a?(Array) ? category_data.first : category_data
    end

    def id
      @id ||= @category['id']
    end

    def primary_category
      @primary_category ||= @category['primary_category']
    end

    def all_categories
      @all_categories ||= @category['categories']
    end
  end
end
