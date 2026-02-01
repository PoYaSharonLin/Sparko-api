# frozen_string_literal: true

module Sparko
  # Summary Mapper Object
  class SummaryMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      Sparko::Entity::Summary.new(@hash['summary'])
    end
  end
end
