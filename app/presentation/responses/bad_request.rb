# frozen_string_literal: true

require 'json'

module AcaRadar
  module Response
    # Represents a Bad Request (400) response
    class BadRequest
      def initialize(representer)
        @representer = representer
      end

      def status
        400
      end

      def to_json(*)
        @representer.to_json(*)
      end
    end
  end
end
