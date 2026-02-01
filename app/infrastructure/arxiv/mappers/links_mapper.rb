# frozen_string_literal: true

module Sparko
  # Links Mapper Object
  class LinksMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      Sparko::Entity::Links.new(@hash['links'])
    end
  end
end
