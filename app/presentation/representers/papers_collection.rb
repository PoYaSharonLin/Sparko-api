# frozen_string_literal: true

module AcaRadar
  module Representer
    # class for the paper collections
    class PapersCollection < Representer::Base
      collection :data,
                 decorator: Representer::Paper,
                 class: Entity::Paper
    end
  end
end
