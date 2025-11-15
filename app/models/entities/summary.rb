# frozen_string_literal: true

module AcaRadar
  # Holds the summary of the paper
  module Entity
    # Represents summary of the paper
    class Summary
      attr_reader :full_summary, :short_summary

      def initialize(text)
        unless text.is_a?(String) || text.is_a?(Array)
          raise ArgumentError,
                'Summary must be initialized with a String or Array'
        end

        full_text = text.is_a?(Array) ? text.join("\n").strip : text.to_s.strip
        @full_summary = full_text
        @short_summary = truncate_to_100_words(full_text)
      end

      def to_s
        short_summary
      end

      private

      def truncate_to_100_words(text)
        words = text.split(/\s+/)
        if words.length > 100
          "#{words[0..99].join(' ')}..."
        else
          text
        end
      end
    end
  end
end
