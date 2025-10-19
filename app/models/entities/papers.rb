#frozen_string_literal: true

require_relative '../mappers/author_mapper'
require_relative '../mappers/categories_mapper'
require_relative '../mappers/links_mapper'

module AcaRadar
  #Represents a single paper entry from the arXiv API, including metadata such as title, authors, categories, and links
  class Paper
    attr_reader :id, :title, :published, :updated, :summary, :authors, :categories, :links, :journal_ref

    def initialize(paper_hash)
      assign_basic_fields(paper_hash)
      # @summary = Summary.new(paper_hash['summary'])
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
