# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

require_relative 'base'
require_relative 'research_interest'
require_relative 'papers_collection'

module AcaRadar
  module Representer
    # class for response in each page of papers
    class PapersPageResponse < Representer::Base
      include Roar::JSON

      property :research_interest_term
      property :research_interest_2d

      property :journals, exec_context: :decorator

      property :papers, decorator: Representer::PapersCollection, pass_options: true

      property :pagination, exec_context: :decorator

      def journals
        represented.journals
      end

      def pagination
        represented.papers.pagination
      end
    end
  end
end
