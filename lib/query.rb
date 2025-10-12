# frozen_string_literal: true

module AcaRadar
  # Query object to set up query parameters (reek hot fix)
  class Query
    # include ArXivConfig

    attr_reader :url

    def initialize(base_query: BASE_QUERY,
                   min_date: MIN_DATE_ARXIV,
                   max_date: MAX_DATE_ARXIV,
                   max_results: 50,
                   sort_by: SORT_BY,
                   sort_order: SORT_ORDER)
      @query = "#{base_query} AND submittedDate:[#{min_date} TO #{max_date}]"
      @url = "https://export.arxiv.org/api/#{build_query(max_results, sort_by, sort_order)}"
    end

    def build_query(max_results, sort_by, sort_order)
      URI.encode_www_form(
        'search_query' => @query,
        'start' => 0,
        'max_results' => max_results,
        'sortBy' => sort_by,
        'sortOrder' => sort_order
      )
    end
  end
end
