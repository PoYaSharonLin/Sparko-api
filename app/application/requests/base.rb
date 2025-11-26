# frozen_string_literal: true

module AcaRadar
  module Request
    # class for base request for other request
    class Base
      attr_reader :params

      def initialize(roda_request_or_params)
        @params = if roda_request_or_params.respond_to?(:params)
                    roda_request_or_params.params
                  else
                    roda_request_or_params
                  end
      end
    end
  end
end
