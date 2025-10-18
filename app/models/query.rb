# frozen_string_literal: true

module AcaRadar
  # Query object to set up query parameters (reek hot fix)
  class Query
    # include ArXivConfig

    attr_reader :url

    # rubocop:disable Metrics/ParameterLists
    def initialize(base_query: ArXivConfig::BASE_QUERY,
                   min_date: ArXivConfig::MIN_DATE_ARXIV,
                   max_date: ArXivConfig::MAX_DATE_ARXIV,
                   journals: ArXivConfig::JOURNALS,
                   max_results: ArXivConfig::MAX_RESULTS,
                   sort_by: ArXivConfig::SORT_BY,
                   sort_order: ArXivConfig::SORT_ORDER)
      normalized_base = if base_query.is_a?(Array)
                          base_query.compact.join(' ')
                        else
                          base_query.to_s
                        end
      normalized_base = normalized_base.to_s.strip
      @query =
        if normalized_base.empty?
          "submittedDate:[#{min_date} TO #{max_date}]"
        else
          "#{normalized_base} AND submittedDate:[#{min_date} TO #{max_date}]"
        end
      if journals.any?
        journal_conditions = journals.map { |j| "jr:\"#{j.strip.gsub('"', '\"')}\"" }.join(' OR ')
        @query += " AND (#{journal_conditions})"
      end
      @url = "https://export.arxiv.org/api/query?#{build_query(max_results, sort_by, sort_order)}"
      warn "[Query] search_query=#{@query.inspect} url=#{@url}"
    end
    # rubocop:enable Metrics/ParameterLists

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
