# frozen_string_literal: true

require_relative '../orm/paper_orm'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/Metrics/MethodLength
module AcaRadar
  module Repository
    # Repository for Papers
    class Paper
      def self.find_by_origin_id(origin_id)
        db_record = Database::PaperOrm.first(origin_id:)
        rebuild_entity(db_record)
      end

      def self.find_many_by_ids(origin_ids)
        origin_ids.map { |origin_id| find_by_origin_id(origin_id) }.compact
      end

      def self.find_title(title)
        rebuild_entity Database::PaperOrm.first(title:)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        paper_entity = Entity::Paper.allocate

        paper_entity.instance_variable_set(:@origin_id, db_record.origin_id)
        paper_entity.instance_variable_set(:@title, db_record.title)
        paper_entity.instance_variable_set(:@published, db_record.published)
        paper_entity.instance_variable_set(:@links, [])
        paper_entity.instance_variable_set(:@authors, deserialize_authors(db_record.authors))
        paper_entity.instance_variable_set(:@summary, db_record.summary)
        paper_entity.instance_variable_set(:@short_summary, db_record.short_summary)
        paper_entity.instance_variable_set(:@concepts, JSON.parse(db_record.concepts || '[]'))
        paper_entity.instance_variable_set(:@embedding, JSON.parse(db_record.embedding || '[]').map(&:to_f))
        paper_entity.instance_variable_set(:@two_dim_embedding,
                                           JSON.parse(db_record.two_dim_embedding || '[]').map(&:to_f))
        paper_entity.instance_variable_set(:@categories, JSON.parse(db_record.categories || '[]'))
        paper_entity.instance_variable_set(:@fetched_at, db_record.fetched_at)

        paper_entity
      end

      def self.rebuild_many(db_records)
        db_records.map do |db_paper|
          Papers.rebuild_entity(db_paper)
        end
      end

      def self.create_or_update(attributes)
        serialized_attrs = attributes.merge(
          authors: serialize_authors(attributes[:authors]), # Adjust based on structure
          concepts: JSON.generate(attributes[:concepts] || []),
          embedding: JSON.generate(attributes[:embedding] || []),
          two_dim_embedding: JSON.generate(attributes[:two_dim_embedding] || []),
          categories: JSON.generate(attributes[:categories] || []),
          links: serialize_links(attributes[:links])
        ).compact

        existing = Database::PaperOrm.where(origin_id: attributes[:origin_id]).first
        if existing
          existing.update(serialized_attrs)
        else
          Database::PaperOrm.create(serialized_attrs)
        end
      end

      def self.serialize_authors(authors)
        return '[]' if authors.nil? || authors.empty?

        JSON.generate(authors.map { |author| { name: author.name } }) # Or author.to_h if it has to_h
      end

      def self.deserialize_authors(json_str)
        return [] if json_str.nil? || json_str.empty?

        JSON.parse(json_str).map { |hash| Entity::Author.new(name: hash['name']) } # Adjust to your Entity::Author
      end

      def self.serialize_links(links)
        return '{}' if links.nil?

        JSON.generate(links.to_h) # Or if it's a struct/object
      end

      def self.deserialize_links(json_str)
        return {} if json_str.nil? || json_str.empty?

        JSON.parse(json_str) # Or recreate Value::Links.new(...)
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/Metrics/MethodLength
