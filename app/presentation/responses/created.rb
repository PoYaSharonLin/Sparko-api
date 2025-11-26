# frozen_string_literal: true

require 'json'

module AcaRadar
  module Response
    # class for created resource
    class Created
      def initialize(representer)
        @representer = representer
      end

      def status
        201
      end

      def to_json(*)
        @representer.to_json(*)
      end
    end
  end
end
