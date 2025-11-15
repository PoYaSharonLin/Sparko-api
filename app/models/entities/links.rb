# frozen_string_literal: true

module AcaRadar
  module Entity
    # Represents links, include pdf link, html link, reference link
    class Links
      attr_reader :links

      def initialize(links)
        @links = normalize_to_array(links)
      end

      def pdf_href
        find_link_by_conditions(
          ->(link) { link['rel'] == 'related' },
          ->(link) { link['title']&.downcase == 'pdf' },
          ->(link) { link['type']&.include?('pdf') }
        )
      end

      def html_href
        find_link_by_conditions(
          ->(link) { link['rel'] == 'alternate' }
        ) || @links.first&.fetch('href', nil)
      end

      def href_by_rel(rel)
        @links.find { |link| link['rel'] == rel }&.fetch('href', nil)
      end

      def to_h
        @links
      end

      private

      def normalize_to_array(links)
        case links
        when Array then links
        when Hash  then [links]
        else []
        end
      end

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
