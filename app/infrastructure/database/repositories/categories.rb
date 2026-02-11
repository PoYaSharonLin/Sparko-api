# frozen_string_literal: true

module Sparko
  module Repository
    # Repository for Categories
    class Category
      def self.find_id(id)
        rebuild_entity Database::CategoryOrm.first(id: id)
      end

      def self.find_name(display_name)
        rebuild_entity Database::CategoryOrm.first(display_name: display_name)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Category.new(
          id: db_record.id,
          arxiv_name: db_record.arxiv_name,
          display_name: db_record.display_name
        )
      end

      def self.rebuild_many(db_records)
        db_records.map do |db_category|
          Categories.rebuild_entity(db_category)
        end
      end

      def self.db_find_or_create(entity)
        Database::CategoryOrm.find_or_create(entity.to_attr_hash)
      end
    end
  end
end
