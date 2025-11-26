# frozen_string_literal: true

require_relative 'base'
require 'ostruct'

module AcaRadar
  module Representer
    # class that represents the error response of the API with error and details
    class Error < Representer::Base
      property :error
      property :details

      def self.validation(term:)
        new(OpenStruct.new(
              error: 'Validation Error',
              details: { invalid_parameters: term }
            ))
      end

      def self.generic(message)
        if message.is_a?(String)
          new(OpenStruct.new(error: 'Error', details: message))
        else
          new(OpenStruct.new(error: 'Error', details: message.to_s))
        end
      end
    end
  end
end
