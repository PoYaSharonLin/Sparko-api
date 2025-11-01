# frozen_string_literal: true

module AcaRadar
  # Summary Mapper Object
  class SummaryMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      AcaRadar::Entity::Summary.new(@hash['summary'])
    end
  end
end
