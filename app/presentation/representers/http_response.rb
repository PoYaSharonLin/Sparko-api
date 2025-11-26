# frozen_string_literal: true

require_relative 'base'

module AcaRadar
  module Representer
    # class that represents the response of the API with status and messages
    class HttpResponse < Representer::Base
      property :status
      property :message
    end
  end
end
