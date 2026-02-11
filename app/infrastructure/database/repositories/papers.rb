# frozen_string_literal: true

require 'time'

require_relative '../orm/paper_orm'
require_relative '../orm/author_orm'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity

module Sparko
  module Repository
    # Repository for Papers
    class Paper
      def self.all
        Database::PaperOrm.all.map { |db_record| rebuild_entity(db_record) }
      end

      def self.find_by_origin_id(origin_id)
        db_record = Database::PaperOrm.first(origin_id: origin_id)
        rebuild_entity(db_record)
      end

      def self.find_many_by_ids(origin_ids)
        origin_ids.map { |origin_id| find_by_origin_id(origin_id) }.compact
      end

      def self.find_title(title)
        rebuild_entity Database::PaperOrm.first(title: title)
      end

      # Filter by stored journal + optional published date range.
      # NOTE: This relies on papers.journal being populated by the fetch script.
      def self.find_by_categories(journals, limit: 50, offset: 0, min_date: nil, max_date: nil)
        journals = Array(journals).map { |j| j.to_s.strip }.reject(&:empty?).uniq

        ds = Database::PaperOrm.dataset

        if Database::PaperOrm.columns.include?(:journal) && journals.any?
          ds = ds.where(journal: journals)
        end

        # Date filter on `published` (works for DateTime and ISO-8601-ish strings in most DBs)
        min_t = normalize_time_start(min_date)
        max_t = normalize_time_end(max_date)

        if min_t && Database::PaperOrm.columns.include?(:published)
          ds = ds.where { published >= min_t }
        end

        if max_t && Database::PaperOrm.columns.include?(:published)
          ds = ds.where { published <= max_t }
        end

        ds = ds.order(Sequel.desc(:published)) if Database::PaperOrm.columns.include?(:published)

        records = ds.limit(limit).offset(offset).all

        # Soft warning: if journal column exists but nothing matches, you're probably not backfilled yet
        if Database::PaperOrm.columns.include?(:journal) && journals.any? && records.empty?
          warn "[Repository::Paper] No rows matched journals=#{journals.inspect}. Did you run migrations + re-fetch to backfill papers.journal?"
        end

        records.map { |db_record| rebuild_entity(db_record) }.compact
      end


      def self.count_by_categories(journals, min_date: nil, max_date: nil)
        journals = Array(journals).map { |j| j.to_s.strip }.reject(&:empty?).uniq
        ds = Database::PaperOrm.dataset
      
        if Database::PaperOrm.columns.include?(:journal) && journals.any?
          ds = ds.where(journal: journals)
        end
      
        min_t = normalize_time_start(min_date)
        max_t = normalize_time_end(max_date)
      
        ds = ds.where { published >= min_t } if min_t && Database::PaperOrm.columns.include?(:published)
        ds = ds.where { published <= max_t } if max_t && Database::PaperOrm.columns.include?(:published)
      
        ds.count
      end
      

      def self.rebuild_entity(db_record)
        return nil unless db_record

        paper_entity = Entity::Paper.allocate

        paper_entity.instance_variable_set(:@origin_id, db_record.origin_id)
        paper_entity.instance_variable_set(:@title, db_record.title)
        paper_entity.instance_variable_set(:@published, db_record.published)
        paper_entity.instance_variable_set(:@links, deserialize_links(db_record.links))
        paper_entity.instance_variable_set(:@journal, db_record[:journal]) if db_record.values.key?(:journal)

        raw_authors =
          if db_record.values.key?(:authors) && db_record[:authors]
            db_record[:authors]                      # JSON column present in selected fields
          else
            # If the column wasn't selected, fetch it cheaply by id
            Database::PaperOrm.where(paper_id: db_record.paper_id).get(:authors)
          end

        paper_entity.instance_variable_set(:@authors, deserialize_authors(raw_authors))
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
      
        paper = Database::PaperOrm.where(origin_id: attributes[:origin_id]).first
        if paper
          paper.update(serialized_attrs)
        else
          paper = Database::PaperOrm.create(serialized_attrs)
        end

        sync_authors!(paper.paper_id, attributes[:authors])
        paper
      end
      
      
      def self.sync_authors!(paper_id, authors)
        return if paper_id.nil? || authors.nil? || authors.empty?
      
        join = Database::PaperOrm.db[:paper_authors]
      
        authors.each do |author|
          name = author.respond_to?(:name) ? author.name : (author[:name] || author['name'])
          name = name.to_s.strip
          next if name.empty?
      
          author_row = Database::AuthorOrm.find_or_create(name: name)
      
          begin
            join.insert(paper_id: paper_id, author_id: author_row.author_id)
          rescue Sequel::UniqueConstraintViolation
          end
        end
      end      

      def self.serialize_authors(authors)
        return '[]' if authors.nil? || authors.empty?

        JSON.generate(authors.map { |author| { name: author.name } })
      end

      def self.deserialize_authors(authors_data)
        return [] if authors_data.nil? || authors_data == '' || authors_data == []
      
        items = authors_data.is_a?(String) ? JSON.parse(authors_data) : Array(authors_data)
      
        items.map do |h|
          name = h.is_a?(Hash) ? (h['name'] || h[:name]) : (h.respond_to?(:name) ? h.name : h.to_s)
          Entity::Author.new(name: name.to_s.strip)
        end.reject { |a| a.name.to_s.strip.empty? }
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

      def self.normalize_time_start(val)
        return nil if val.nil? || val == :invalid
      
        t =
          case val
          when Date
            Time.utc(val.year, val.month, val.day, 0, 0, 0)
          when Time
            Time.utc(val.year, val.month, val.day, 0, 0, 0)
          else
            # accept "YYYY-MM-DD" or ISO8601
            Time.parse(val.to_s)
          end
      
        Time.utc(t.year, t.month, t.day, 0, 0, 0)
      rescue StandardError
        nil
      end
      private_class_method :normalize_time_start
      
      def self.normalize_time_end(val)
        return nil if val.nil? || val == :invalid
      
        t =
          case val
          when Date
            Time.utc(val.year, val.month, val.day, 23, 59, 59)
          when Time
            Time.utc(val.year, val.month, val.day, 23, 59, 59)
          else
            Time.parse(val.to_s)
          end
      
        Time.utc(t.year, t.month, t.day, 23, 59, 59)
      rescue StandardError
        nil
      end
      private_class_method :normalize_time_end      
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/Metrics/MethodLength
# rubocop:enable Metrics/PerceivedComplexity
