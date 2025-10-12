# frozen_string_literal: true

require 'yaml'
require 'http'
require 'rexml/document'

module AcaRadar
  # Library for API parser
  class ArXivApiParser
    module Errors
      class NotFound < StandardError; end
      class Unauthorized < StandardError; end
    end

    HTTP_ERROR = {
      401 => Errors::Unauthorized,
      404 => Errors::NotFound
    }.freeze

    def arxiv_api_path(path)
      "https://export.arxiv.org/api/#{path}"
    end

    def call_arxiv_url(config, url)
      ua = config['ARXIV_USER_AGENT'].to_s
      result =
        HTTP.headers(
          'Accept' => 'application/atom+xml',
          'User-Agent' => ua
        ).get(url)
      successful?(result) ? result : raise(HTTP_ERROR[result.code])
    end

    def successful?(result)
      !HTTP_ERROR.keys.include?(result.code)
    end

    def parse_xml(xml_str)
      REXML::Document.new(xml_str)
    end

    # Extracts pagination metadata from the XML document
    def extract_pagination_metadata(doc)
      {
        'total_results' => REXML::XPath.first(doc, '//opensearch:totalResults')&.text&.to_i,
        'start_index' => REXML::XPath.first(doc, '//opensearch:startIndex')&.text&.to_i,
        'items_per_page' => REXML::XPath.first(doc, '//opensearch:itemsPerPage')&.text&.to_i
      }.compact
    end

    # Extracts basic fields (id, title, summary, published, updated) from an entry
    def extract_entry_fields(entry)
      fields = %w[id title summary published updated]
      fields.each_with_object({}) do |field, hash|
        value = entry.elements[field]&.text
        hash[field] = value&.strip if value
      end
    end

    # Extracts authors from an entry
    def extract_authors(entry)
      entry.get_elements('author/name').map { |n| n.text.to_s.strip }.uniq
    end

    # Extracts categories and primary category from an entry
    def extract_categories(entry)
      {
        'categories' => entry.get_elements('category').map { |c| c.attributes['term'] }.compact.uniq,
        'primary_category' => entry.elements['arxiv:primary_category']&.attributes&.[]('term')
      }.compact
    end

    # Extracts links from an entry
    def extract_links(entry)
      entry.get_elements('link').map do |l|
        {
          'rel' => l.attributes['rel'],
          'type' => l.attributes['type'],
          'href' => l.attributes['href'],
          'title' => l.attributes['title']
        }.compact
      end
    end

    # Parses a single entry into a hash
    def parse_entry(entry)
      entry_fields = extract_entry_fields(entry)
      authors = extract_authors(entry)
      categories = extract_categories(entry)
      links = extract_links(entry)

      entry_fields.merge(
        'authors' => authors,
        'categories' => categories['categories'],
        'primary_category' => categories['primary_category'],
        'links' => links
      ).compact
    end

    # Main function to parse the arXiv ATOM feed
    def parse_arxiv_atom(xml_str)
      doc = parse_xml(xml_str)
      pagination_metadata = extract_pagination_metadata(doc)

      entries = REXML::XPath.each(doc, '//entry').map { |entry| parse_entry(entry) }

      pagination_metadata.merge('entries' => entries).compact
    end
  end
end
