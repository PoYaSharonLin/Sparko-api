# frozen_string_literal: true

require 'dry-validation'

module AcaRadar
  module Request
    # class that validate the form of research interest
    class EmbedResearchInterest
      def initialize(params)
        @term = params['term']&.strip
      end

      attr_reader :term

      def valid?
        term.is_a?(String) &&
          term.strip != '' &&
          term.strip =~ /\A[\w\s-]+\z/
      end
    end
  end
end
