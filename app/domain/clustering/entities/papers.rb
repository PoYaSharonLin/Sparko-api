# frozen_string_literal: true

require_relative '../../../infrastructure/arxiv/mappers/author_mapper'
require_relative '../../../infrastructure/arxiv/mappers/categories_mapper'
require_relative '../../../infrastructure/arxiv/mappers/links_mapper'
require_relative '../../../infrastructure/arxiv/mappers/summary_mapper'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/MethodLength

module AcaRadar
  # Domain entity module
  module Entity
    # Represents a single paper entry from the arXiv API, including title, authors, categories, and links
    class Paper
      attr_reader :origin_id, :title, :published, :updated, :summary, :short_summary,
                  :authors, :categories, :links, :journal_ref, :concepts, :embedding,
                  :two_dim_embedding, :fetched_at

      def initialize(paper_hash)
        @origin_id = paper_hash['id'] || paper_hash[:origin_id]
        assign_basic_fields(paper_hash)
        @summary = SummaryMapper.new(paper_hash).build_entity
        @authors = AuthorMapper.new(paper_hash).build_entity
        @categories = CategoriesMapper.new(paper_hash).build_entity
        @links = LinksMapper.new(paper_hash).build_entity
        @concepts = paper_hash['concepts'] || paper_hash[:concepts] || []
        @embedding = (paper_hash['embedding'] || paper_hash[:embedding] || []).map(&:to_f)
        @two_dim_embedding = (paper_hash['two_dim_embedding'] || paper_hash[:two_dim_embedding] || []).map(&:to_f)
        @fetched_at = paper_hash['fetched_at'] || paper_hash[:fetched_at]
      end

      def pdf_url
        pdf_link = @links.find { |link| link['type'] == 'application/pdf' }
        pdf_link ? pdf_link['href'] : nil
      end

      def to_attr_hash
        {
          origin_id: @origin_id,
          title: @title,
          published: @published,
          updated: @updated,
          summary: @summary,
          journal_ref: @journal_ref,
          concepts: @concepts,
          embedding: @embedding,
          two_dim_embedding: @two_dim_embedding,
          fetched_at: @fetched_at
        }
      end

      def published_at
        @published
      end

      def primary_category
        @categories&.first
      end

      def embedding_2d
        @two_dim_embedding
      end

      private

      def assign_basic_fields(hash)
        @id = hash['id']
        @title = hash['title']
        @published = hash['published']
        @updated = hash['updated']
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity
# rubocop:enable Metrics/MethodLength
