# frozen_string_literal: true

require_relative '../orm/paper_orm'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity

module AcaRadar
  module Repository
    # Repository for Papers
    class Paper
      def self.all
        Database::PaperOrm.all.map { |db_record| rebuild_entity(db_record) }
      end

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

      # hot fix, not using journal as category yet
      def self.find_by_categories(_categories, limit: 50, offset: 0)
        Database::PaperOrm.limit(limit).offset(offset).map { |db_record| rebuild_entity(db_record) }
      end

      # hot fix, not using journal as category yet
      def self.count_by_categories(_categories)
        Database::PaperOrm.count
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        paper_entity = Entity::Paper.allocate

        paper_entity.instance_variable_set(:@origin_id, db_record.origin_id)
        paper_entity.instance_variable_set(:@title, db_record.title)
        paper_entity.instance_variable_set(:@published, db_record.published)
        paper_entity.instance_variable_set(:@links, deserialize_links(db_record.links))
        paper_entity.instance_variable_set(:@authors, deserialize_authors(db_record.authors))
        paper_entity.instance_variable_set(:@summary, db_record.summary)
        paper_entity.instance_variable_set(:@short_summary, db_record.short_summary)
        concepts_data = db_record.concepts || '[]'
        concepts = concepts_data.is_a?(String) ? JSON.parse(concepts_data) : concepts_data
        paper_entity.instance_variable_set(:@concepts, concepts)

        embedding_data = db_record.embedding || '[]'
        embedding = embedding_data.is_a?(String) ? JSON.parse(embedding_data) : embedding_data
        paper_entity.instance_variable_set(:@embedding, embedding.map(&:to_f))

        two_dim_data = db_record.two_dim_embedding || '[]'
        two_dim_embedding = two_dim_data.is_a?(String) ? JSON.parse(two_dim_data) : two_dim_data
        paper_entity.instance_variable_set(:@two_dim_embedding, two_dim_embedding.map(&:to_f))

        categories_data = db_record.categories || '[]'
        categories = categories_data.is_a?(String) ? JSON.parse(categories_data) : categories_data
        paper_entity.instance_variable_set(:@categories, categories)

        paper_entity.instance_variable_set(:@fetched_at, db_record.fetched_at)

        paper_entity
      end

      def self.rebuild_many(db_records)
        db_records.map do |db_paper|
          Paper.rebuild_entity(db_paper)
        end
      end

      def self.create_or_update(attributes)
        serialized_attrs = attributes.merge(
          authors: serialize_authors(attributes[:authors]),
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

        JSON.generate(authors.map { |author| { name: author.name } })
      end

      def self.deserialize_authors(authors_data)
        return [] if authors_data.nil? || authors_data.empty?

        authors = authors_data.is_a?(String) ? JSON.parse(authors_data) : authors_data
        authors.map { |hash| Entity::Author.new(name: hash['name']) }
      end

      def self.serialize_links(links)
        return '{}' if links.nil?

        JSON.generate(links.to_h)
      end

      def self.deserialize_links(json_str)
        return {} if json_str.nil? || json_str.empty?

        JSON.parse(json_str)
      end

      def self.origin_id_and_embeddings
        Database::PaperOrm.select(:origin_id, :embedding).all.map do |r|
          raw = r.embedding || '[]'
          emb = raw.is_a?(String) ? JSON.parse(raw) : raw
          emb = Array(emb).map(&:to_f)
          { origin_id: r.origin_id, embedding: emb }
        rescue JSON::ParserError
          # skip broken embedding rows safely
          nil
        end.compact
      end

      def self.update_two_dim_embedding(origin_id, two_dim)
        Database::PaperOrm.where(origin_id: origin_id).update(
          two_dim_embedding: JSON.generate(Array(two_dim))
        )
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/Metrics/MethodLength
# rubocop:enable Metrics/PerceivedComplexity
