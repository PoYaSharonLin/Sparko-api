# frozen_string_literal: true

module AcaRadar
  # Links Mapper Object
  class LinksMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      Array(@hash['links'])
    end
  end
end
