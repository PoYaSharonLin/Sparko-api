# frozen_string_literal: true

module AcaRadar
  # Query object to set up query parameters (reek hot fix)
  class Query
    # include ArXivConfig

    attr_reader :url

    # :reek:LongParameterList
    def initialize(
      min_date: ArXivConfig::MIN_DATE_ARXIV,
      max_date: ArXivConfig::MAX_DATE_ARXIV,
      journals: ArXivConfig::JOURNALS,
      max_results: ArXivConfig::MAX_RESULTS,
      sort_by: ArXivConfig::SORT_BY,
      sort_order: ArXivConfig::SORT_ORDER
    )
      @query = "submittedDate:[#{min_date} TO #{max_date}]"
      if journals.any?
        journal_conditions = journals.map { |journal| "jr:\"#{journal.strip.gsub('"', '\"')}\"" }.join(' OR ')
        @query += " AND (#{journal_conditions})"
      end
      @url = "https://export.arxiv.org/api/query?#{build_query(max_results, sort_by, sort_order)}"
      warn "[Query] search_query=#{@query.inspect} url=#{@url}"
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
