# frozen_string_literal: true

require 'yaml'
require 'date'
require_relative 'base'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
module Sparko
  module Request
    # class for listing papers from 1+ journals (canonical names from journals.yml)
    class ListPapers < Base
      JOURNALS_YAML_PATH = File.expand_path('../../../bin/journals.yml', __dir__)

      DEFAULT_TOP_N = 25
      MAX_TOP_N = 200

      def request_id
        (params['request_id'] || params['job_id']).to_s.strip
      end

      def journals
        @journals ||= begin
          values =
            if params.key?('journals') && !params['journals'].nil?
              raw = params['journals']
              raw.is_a?(Array) ? raw : raw.to_s.split(',')
            else
              # Legacy support: journal1, journal2, journal3...
              journal_kv = params.select { |k, _| k.to_s.match?(/\Ajournal\d+\z/) }
              journal_kv.sort_by { |k, _| k.to_s.sub('journal', '').to_i }.map { |_, v| v }
            end

          values.map { |v| v.to_s.strip }.reject(&:empty?).uniq
        end
      end

      def page
        @page ||= begin
          raw = params['page']
          if raw.nil? || raw.to_s.strip.empty?
            1
          elsif raw.to_s.strip.match?(/\A[1-9]\d*\z/)
            raw.to_i
          else
            1 # invalid will be caught by page_provided_valid?
          end
        end
      end

      def offset(default_per_page = 10)
        (page - 1) * default_per_page
      end

      def top_n
        @top_n ||= begin
          raw = params['top_n'] || params['n']
          if raw.nil? || raw.to_s.strip.empty?
            DEFAULT_TOP_N
          elsif raw.to_s.strip.match?(/\A[1-9]\d*\z/)
            raw.to_i
          else
            DEFAULT_TOP_N # invalid will be caught by top_n_provided_valid?
          end
        end
      end

      def min_date
        @min_date ||= parse_iso_date(params['min_date'])
      end

      def max_date
        @max_date ||= parse_iso_date(params['max_date'])
      end

      def valid?
        return false unless page_provided_valid?
        return false if journals.empty?
        return false unless journals.all? { |j| self.class.valid_journal_names.include?(j) }
        return false unless top_n_provided_valid?
        return false unless date_range_valid?

        true
      end

      def error_message
        return 'page must be a positive integer' unless page_provided_valid?
        return 'You must select at least one journal' if journals.empty?

        invalid = journals.reject { |j| self.class.valid_journal_names.include?(j) }
        return "Invalid or unknown journals: #{invalid.join(', ')}" if invalid.any?

        raw_top = params['top_n'] || params['n']
        if raw_top && !raw_top.to_s.strip.empty?
          s = raw_top.to_s.strip
          return 'top_n must be a positive integer' unless s.match?(/\A[1-9]\d*\z/)
          return "top_n must be <= #{MAX_TOP_N}" if s.to_i > MAX_TOP_N
        end

        if min_date == :invalid || max_date == :invalid
          return 'min_date and max_date must be in YYYY-MM-DD format'
        end

        return 'min_date must be <= max_date' unless date_range_valid?

        nil
      end

      def self.valid_journal_names
        @valid_journal_names ||= load_valid_journal_names
      end

      def self.reload_valid_journal_names!
        @valid_journal_names = load_valid_journal_names
      end

      def self.load_valid_journal_names
        return [] unless File.file?(JOURNALS_YAML_PATH)

        data = safe_load_yaml(File.read(JOURNALS_YAML_PATH))
        domains = data.is_a?(Hash) ? (data['domains'] || data[:domains] || {}) : {}
        return [] unless domains.is_a?(Hash)

        names = []
        collect = lambda do |node|
          next unless node.is_a?(Hash)

          jnode = node['journals'] || node[:journals]
          case jnode
          when Array
            jnode.each do |j|
              if j.is_a?(Hash)
                n = j['name'] || j[:name]
                names << n if n
              else
                names << j
              end
            end
          when Hash
            jnode.each_key { |k| names << k }
          end

          sub = node['subdomains'] || node[:subdomains]
          sub.each_value { |sd| collect.call(sd) } if sub.is_a?(Hash)
        end

        domains.each_value { |node| collect.call(node) }

        names.map { |n| n.to_s.strip }.reject(&:empty?).uniq
      rescue StandardError => e
        warn "[ListPapers] Failed to load journals.yml: #{e.class}: #{e.message}"
        []
      end
      private_class_method :load_valid_journal_names

      def self.safe_load_yaml(raw)
        YAML.safe_load(raw, permitted_classes: [], permitted_symbols: [], aliases: true) || {}
      rescue ArgumentError
        YAML.safe_load(raw, [], [], true) || {}
      end
      private_class_method :safe_load_yaml

      private

      def page_provided_valid?
        raw = params['page']
        return true if raw.nil? || raw.to_s.strip.empty?

        raw.to_s.strip.match?(/\A[1-9]\d*\z/)
      end

      def top_n_provided_valid?
        raw = params['top_n'] || params['n']
        return true if raw.nil? || raw.to_s.strip.empty?

        s = raw.to_s.strip
        return false unless s.match?(/\A[1-9]\d*\z/)

        s.to_i <= MAX_TOP_N
      end

      def date_range_valid?
        return false if min_date == :invalid || max_date == :invalid
        return true if min_date.nil? || max_date.nil?

        min_date <= max_date
      end

      def parse_iso_date(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?

        Date.iso8601(raw.to_s.strip)
      rescue ArgumentError
        :invalid
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity
