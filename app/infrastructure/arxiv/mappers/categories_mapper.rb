# frozen_string_literal: true

module Sparko
  # Categories Mapper Object
  class CategoriesMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      Sparko::Entity::Categories.new(@hash['categories'], @hash['primary_category'])
    end
  end
end
