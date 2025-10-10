require 'yaml'
require 'http'
require 'rexml/document'

module AcaRadar
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

    def parse_arxiv_atom(xml_str)
      doc = REXML::Document.new(xml_str)

      total_results = REXML::XPath.first(doc, '//opensearch:totalResults')&.text&.to_i
      start_index   = REXML::XPath.first(doc, '//opensearch:startIndex')&.text&.to_i
      items_per_pg  = REXML::XPath.first(doc, '//opensearch:itemsPerPage')&.text&.to_i

      entries = []
      REXML::XPath.each(doc, '//entry') do |e|
        title     = e.elements['title']&.text&.strip
        summary   = e.elements['summary']&.text&.strip
        published = e.elements['published']&.text&.strip
        updated   = e.elements['updated']&.text&.strip
        id        = e.elements['id']&.text&.strip

        authors = e.get_elements('author/name').map { |n| n.text.to_s.strip }.uniq
        cats    = e.get_elements('category').map { |c| c.attributes['term'] }.compact.uniq
        pcat    = e.elements['arxiv:primary_category']&.attributes&.[]('term')

        links = e.get_elements('link').map do |l|
          {
            'rel'   => l.attributes['rel'],
            'type'  => l.attributes['type'],
            'href'  => l.attributes['href'],
            'title' => l.attributes['title']
          }.compact
        end

        entries << {
          'id'  => id,
          'title' => title,
          'summary' => summary,
          'published' => published,
          'updated' => updated,
          'authors' => authors,
          'categories' => cats,
          'primary_category' => pcat,
          'links' => links
        }.compact
      end

      {
        'total_results' => total_results,
        'start_index' => start_index,
        'items_per_page' => items_per_pg,
        'entries' => entries
      }.compact
    end
  end
end