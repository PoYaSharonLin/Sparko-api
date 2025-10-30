# frozen_string_literal: true

# app/entities/links.rb
module AcaRadar
  module Entity
    # Handles link extraction from arXiv API responses
    # arXiv entries typically contain multiple links (PDF, HTML, DOI, etc.)
    class Links
      attr_reader :links

      # @param links [Array<Hash>, Hash] Raw link data from arXiv API
      # Examples:
      #   - Single link: { 'href' => 'url', 'rel' => 'alternate' }
      #   - Multiple links: [{ 'href' => '...', 'rel' => '...' }, ...]
      def initialize(links)
        @links = normalize_to_array(links)
      end

      # Returns the PDF download link
      # Searches in priority order:
      #   1. Link with rel='related' (arXiv standard for PDF)
      #   2. Link with title='pdf' (case-insensitive)
      #   3. Link with type containing 'pdf'
      # @return [String, nil] PDF URL or nil if not found
      def pdf_href
        find_link_by_conditions(
          ->(link) { link['rel'] == 'related' },
          ->(link) { link['title']&.downcase == 'pdf' },
          ->(link) { link['type']&.include?('pdf') }
        )
      end

      # Returns the HTML page link (main article page)
      # @return [String, nil] HTML URL, defaults to first link if no alternate found
      def html_href
        find_link_by_conditions(
          ->(link) { link['rel'] == 'alternate' }
        ) || @links.first&.fetch('href', nil)
      end

      # Flexible method to get link by relationship type
      # @param rel [String] Relationship type (e.g., 'alternate', 'related', 'doi')
      # @return [String, nil] Matching URL or nil
      def href_by_rel(rel)
        @links.find { |link| link['rel'] == rel }&.fetch('href', nil)
      end

      private

      # Converts input to consistent Array<Hash> format
      # @param links [Array, Hash, Object] Raw input
      # @return [Array<Hash>] Normalized array of link hashes
      def normalize_to_array(links)
        case links
        when Array then links
        when Hash  then [links]
        else []
        end
      end

      # Tries multiple conditions in order, returns first matching href
      # @param conditions [Array<Proc>] Lambda conditions to test each link
      # @return [String, nil] First matching href or nil
      def find_link_by_conditions(*conditions)
        conditions.each do |condition|
          matching_link = @links.find { |link| condition.call(link) }
          return matching_link['href'] if matching_link
        end
        nil
      end
    end
  end
end
