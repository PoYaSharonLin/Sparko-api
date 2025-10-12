# frozen_string_literal: true

module AcaRadar
  # Represents a single paper entry from the arXiv API, including metadata such as title, authors, categories, and links
  class Paper
    attr_reader :id, :title, :published, :updated, :summary, :authors, :categories, :links

    def initialize(paper_hash)
      assign_basic_fields(paper_hash)
      # @summary = Summary.new(paper_hash['summary'])
      @authors = build_authors(paper_hash)
      @categories = build_categories(paper_hash)
      @links = build_links(paper_hash)
    end

    private

    def assign_basic_fields(hash)
      @id = hash['id']
      @title = hash['title']
      @published = hash['published']
      @updated = hash['updated']
    end

    def build_authors(hash)
      Array(hash['authors']).map { |name| Author.new(name) }
    end

    def build_categories(hash)
      Categories.new(hash['categories'], hash['primary_category'])
    end

    def build_links(hash)
      Array(hash['links'])
    end
  end
end
