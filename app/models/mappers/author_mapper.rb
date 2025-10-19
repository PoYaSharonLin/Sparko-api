# frozen_string_literal: true

module AcaRadar
  # Author Mapper Object
  class AuthorMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      Array(@hash['authors']).map { |name| Author.new(name) }
    end
  end
end
