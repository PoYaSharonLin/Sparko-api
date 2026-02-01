# frozen_string_literal: true

module Sparko
  # Author Mapper Object
  class AuthorMapper
    def initialize(hash)
      @hash = hash
    end

    def build_entity
      Array(@hash['authors']).map { |name| Sparko::Entity::Author.new(name) }
    end
  end
end
