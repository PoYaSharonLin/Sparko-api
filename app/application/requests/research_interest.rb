# frozen_string_literal: true

module Sparko
  module Request
    class EmbedResearchInterest
      MAX_LEN = 500

      attr_reader :term

      def initialize(params)
        @term = params['term']
      end

      def valid?
        @error_code = nil
        @error_message = nil

        unless term.is_a?(String)
          set_error(:empty, "Research interest must be a string.")
          return false
        end

        t = term.strip
        if t.empty?
          set_error(:empty, "Research interest cannot be empty.")
          return false
        end

        if t.length > MAX_LEN
          set_error(:too_long, "Research interest must be under #{MAX_LEN} characters.")
          return false
        end

        # Allow letters/numbers/whitespace + common punctuation.
        # Reject control chars and weird invisible stuff.
        if t.match?(/[\p{Cntrl}]/u)
          set_error(:invalid_chars, "Please use only letters, numbers, spaces, and standard punctuation.")
          return false
        end

        unless t.match?(/\A[\p{L}\p{N}\s\-\.,;:!?'"()\[\]\/&+@#%]+\z/u)
          set_error(:invalid_chars, "Please use only letters, numbers, spaces, and standard punctuation.")
          return false
        end

        true
      end

      def error_code
        @error_code
      end

      def error_message
        @error_message
      end

      private

      def set_error(code, msg)
        @error_code = code
        @error_message = msg
      end
    end
  end
end
