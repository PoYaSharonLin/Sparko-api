# frozen_string_literal: true

module Sparko
  module Repository
    # Repository for Authors
    class Author
      def self.find_id(id)
        rebuild_entity Database::AuthorOrm.first(id: id)
      end

      def self.find_name(name)
        rebuild_entity Database::AuthorOrm.first(name: name)
      end

      def self.find_last_name(last_name)
        rebuild_entity Database::AuthorOrm.first(last_name: last_name)
      end

      def self.create(entity)
        Database::AuthorOrm.create(
          name: entity.name,
          first_name: entity.first_name,
          last_name: entity.last_name
        )
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record
      
        begin
          Entity::Author.new(
            name: db_record.name,
            first_name: db_record.first_name,
            last_name: db_record.last_name
          )
        rescue ArgumentError
          Entity::Author.new(db_record.name.to_s)
        end
      end
      
    end
  end
end
