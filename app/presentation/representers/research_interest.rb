# frozen_string_literal: true

module AcaRadar
  module Representer
    # class that represent the research interest in the form of 2D vector
    class ResearchInterest < Representer::Base
      property :term

      property :vector_2d, exec_context: :decorator

      def vector_2d
        {
          x: represented.vector_2d[0].round(6),
          y: represented.vector_2d[1].round(6)
        }
      end
    end
  end
end
