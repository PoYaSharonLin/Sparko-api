# frozen_string_literal: true

require 'yaml'
require 'uri'

module Sparko
  # Query object to set up query parameters (reek hot fix)
  class Query
    DEFAULT_JOURNALS_YAML_PATH = File.expand_path('../../../../bin/journals.yml', __dir__)

    attr_reader :url, :search_query

    # :reek:LongParameterList
    def initialize(
      min_date: ArXivConfig::MIN_DATE_ARXIV,
      max_date: ArXivConfig::MAX_DATE_ARXIV,
      journals: ArXivConfig::JOURNALS,
      max_results: ArXivConfig::MAX_RESULTS,
      sort_by: ArXivConfig::SORT_BY,
      sort_order: ArXivConfig::SORT_ORDER,
      start: 0,
      journals_yaml_path: DEFAULT_JOURNALS_YAML_PATH
    )
      @start = start.to_i
      @start = 0 if @start.negative?

      @search_query = "submittedDate:[#{min_date} TO #{max_date}]"

      selected = normalize_list(journals)

      if selected.any?
        alias_index = self.class.journal_alias_index(journals_yaml_path)

        # For each selected journal, build (jr:"alias1" OR jr:"alias2" ...)
        per_journal_groups = selected.map do |canonical_or_alias|
          aliases = alias_index[canonical_or_alias] || [canonical_or_alias]
          aliases = normalize_list(aliases)
          next nil if aliases.empty?

          terms = aliases.map { |a| %(jr:"#{escape_jr_phrase(a)}") }
          terms.length == 1 ? terms.first : "(#{terms.join(' OR ')})"
        end.compact

        # Then OR across selected journals
        @search_query += " AND (#{per_journal_groups.join(' OR ')})" if per_journal_groups.any?
      end

      @url = "https://export.arxiv.org/api/query?#{build_query(max_results, sort_by, sort_order)}"
      warn "[Query] search_query=#{@search_query.inspect} url=#{@url}"
    end

    def build_query(max_results, sort_by, sort_order)
      URI.encode_www_form(
        'search_query' => @search_query,
        'start' => @start,
        'max_results' => max_results,
        'sortBy' => sort_by,
        'sortOrder' => sort_order
      )
    end

    def escape_jr_phrase(str)
      # arXiv uses quotes for phrase matching; escape internal quotes
      str.to_s.strip.gsub('"', '\"')
    end

    class << self
      def journal_alias_index(yaml_path)
        @journal_alias_index ||= {}
        return @journal_alias_index[yaml_path] if @journal_alias_index.key?(yaml_path)

        @journal_alias_index[yaml_path] = load_alias_index(yaml_path)
      end

      private

      def load_alias_index(yaml_path)
        return {} unless yaml_path && File.file?(yaml_path)

        raw = File.read(yaml_path)
        data = safe_yaml_load(raw)

        journals = flatten_journals_from_yaml(data)

        index = {}
        journals.each do |j|
          next unless j.is_a?(Hash)

          name = (j['name'] || j[:name]).to_s.strip
          next if name.empty?

          aliases = j['aliases'] || j[:aliases] || []
          aliases = Array(aliases).map { |a| a.to_s.strip }.reject(&:empty?)
          aliases = ([name] + aliases).uniq

          # Allow lookup by canonical name AND by any alias value
          aliases.each do |key|
            if index.key?(key) && index[key] != aliases
              warn "[Query] journals.yml alias collision on #{key.inspect} (keeping first)"
              next
            end
            index[key] = aliases
          end
        end

        index
      rescue StandardError => e
        warn "[Query] Could not load journals.yml at #{yaml_path}: #{e.class}: #{e.message}"
        {}
      end

      # Psych 4/5 compatibility:
      # - Psych 5: safe_load(yaml, permitted_classes: [], permitted_symbols: [], aliases: true)
      # - Older Psych: safe_load(yaml, [], [], true)
      def safe_yaml_load(raw)
        params = YAML.method(:safe_load).parameters
        if params.any? { |_t, name| name == :aliases }
          YAML.safe_load(raw, permitted_classes: [], permitted_symbols: [], aliases: true) || {}
        else
          YAML.safe_load(raw, [], [], true) || {}
        end
      end

      def flatten_journals_from_yaml(data)
        out = []
        root =
          if data.is_a?(Hash)
            data['domains'].is_a?(Hash) ? data['domains'] : data
          else
            {}
          end

        root.each_value { |node| collect_journals(node, out) }
        out
      end

      def collect_journals(node, out)
        case node
        when Hash
          out.concat(node['journals']) if node['journals'].is_a?(Array)

          if node['subdomains'].is_a?(Hash)
            node['subdomains'].each_value { |sd| collect_journals(sd, out) }
          end

          # Walk nested hashes defensively
          node.each_value { |v| collect_journals(v, out) if v.is_a?(Hash) }
        when Array
          node.each { |v| collect_journals(v, out) }
        end
      end
    end

    private

    def normalize_list(val)
      Array(val).map { |x| x.to_s.strip }.reject(&:empty?).uniq
    end
  end
end
