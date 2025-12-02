# app/presentation/representers/papers_page_response.rb
module AcaRadar
  module Representer
    class PapersPageResponse < Representer::Base
      include Roar::JSON

      property :research_interest_term
      property :research_interest_2d

      property :journals, exec_context: :decorator

      property :papers,
               exec_context: :decorator,
               decorator: Representer::PapersCollection,
               pass_options: true

      property :pagination, exec_context: :decorator

      def journals
        represented.journals
      end

      # `represented.papers` is the OpenStruct from Service::ListPapers
      def papers(_options = {})
        list = represented.papers
        OpenStruct.new(data: list.papers)
      end

      def pagination
        represented.papers.pagination
      end
    end
  end
end
