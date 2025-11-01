# frozen_string_literal: true

require_relative '../../../infrastructure/arxiv/mappers/author_mapper'
require_relative '../../../infrastructure/arxiv/mappers/categories_mapper'
require_relative '../../../infrastructure/arxiv/mappers/links_mapper'
require_relative '../../../infrastructure/arxiv/mappers/summary_mapper'

module AcaRadar
  # Domain entity module
  module Entity
    # Represents a single paper entry from the arXiv API, including title, authors, categories, and links
    class Paper
      attr_reader :id, :title, :published, :updated, :summary, :authors, :categories, :links, :journal_ref

      def initialize(paper_hash)
        assign_basic_fields(paper_hash)
        @summary = SummaryMapper.new(paper_hash).build_entity
        @authors = AuthorMapper.new(paper_hash).build_entity
        @categories = CategoriesMapper.new(paper_hash).build_entity
        @links = LinksMapper.new(paper_hash).build_entity
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
