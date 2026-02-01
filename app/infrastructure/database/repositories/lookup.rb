# frozen_string_literal: true

require_relative 'papers'
require_relative 'authors'
require_relative 'categories'

module Sparko
  module Repository
    # Finds the right repository for an entity object or class
    module Lookup
      ENTITY_REPOSITORY = {
        Entity::Paper => Paper,
        Entity::Author => Author,
        Entity::Categories => Category
      }.freeze

      def self.klass(entity_klass)
        ENTITY_REPOSITORY[entity_klass]
      end

      def self.entity(entity_object)
        ENTITY_REPOSITORY[entity_object.class]
      end
    end
  end
end
