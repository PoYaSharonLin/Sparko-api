# frozen_string_literal: true

require_relative 'base'

module AcaRadar
  module Representer
    # Represents the standardized API envelope
    class HttpResponse < Representer::Base
      property :status
      property :code
      property :message
      property :data
    end
  end
end
