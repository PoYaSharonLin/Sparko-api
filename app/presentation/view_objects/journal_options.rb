# frozen_string_literal: true

require 'yaml'

module Sparko
  module View
    # class for presenting the journal options in frontend
    class JournalOption
      JOURNALS_YAML_PATH = File.expand_path('../../../bin/journals.yml', __dir__)

      FALLBACK = [
        ['MIS Quarterly', 'MIS Quarterly'],
        ['Management Science', 'Management Science'],
        ['Journal of the ACM', 'Journal of the ACM']
      ].freeze

      def self.all
        names = load_canonical_journal_names(JOURNALS_YAML_PATH)

        if names.empty?
          warn "[JournalOption] No canonical journals loaded from #{JOURNALS_YAML_PATH}"
          return FALLBACK
        end

        names.map { |name| [name, name] }
      end

      def self.load_canonical_journal_names(path)
        return [] unless File.file?(path)

        raw = File.read(path)
        data = safe_load_yaml(raw)

        names = []
        collect_canonical_names(data, names)

        names
          .map { |n| n.to_s.strip }
          .reject(&:empty?)
          .uniq
      rescue StandardError => e
        warn "[JournalOption] Failed to load #{path}: #{e.class}: #{e.message}"
        []
      end
      private_class_method :load_canonical_journal_names

      # Supports both:
      # journals: [ {name: "...", aliases: [...]}, ... ]
      # journals: { "Name" => {aliases: [...]}, ... }
      def self.collect_canonical_names(node, out)
        case node
        when Hash
          # Handle top-level "domains" container if present
          domains = node['domains'] || node[:domains]
          if domains.is_a?(Hash)
            domains.each_value { |v| collect_canonical_names(v, out) }
          end

          journals_node = node['journals'] || node[:journals]
          if journals_node.is_a?(Array)
            journals_node.each do |j|
              case j
              when Hash
                name = j['name'] || j[:name]
                # Also support one-key hashes like { "MIS Quarterly" => {aliases: [...] } }
                if name.nil? && j.size == 1
                  name = j.keys.first
                end
                out << name if name
              else
                # string entries: - "MIS Quarterly"
                out << j
              end
            end
          elsif journals_node.is_a?(Hash)
            # keyed-by-name:
            # journals:
            #   "MIS Quarterly": { aliases: [...] }
            journals_node.each_key { |k| out << k }
          end

          subdomains = node['subdomains'] || node[:subdomains]
          if subdomains.is_a?(Hash)
            subdomains.each_value { |v| collect_canonical_names(v, out) }
          end

          # Walk other nested structures defensively (but avoid re-walking the big keys)
          node.each do |k, v|
            next if %w[domains journals subdomains].include?(k.to_s)
            collect_canonical_names(v, out) if v.is_a?(Hash) || v.is_a?(Array)
          end
        when Array
          node.each { |v| collect_canonical_names(v, out) }
        end
      end
      private_class_method :collect_canonical_names

      def self.safe_load_yaml(raw)
        # Prefer keyword form (newer Psych); fall back to positional (older Psych)
        YAML.safe_load(raw, permitted_classes: [], permitted_symbols: [], aliases: true) || {}
      rescue ArgumentError
        YAML.safe_load(raw, [], [], true) || {}
      end
      private_class_method :safe_load_yaml
    end
  end
end
