# frozen_string_literal: true

require 'yaml'

module Sparko
  module Routes
    # Journals routes - /api/v1/journals
    module Journals
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def handle_journals_route(routing)
        routing.get 'journals' do
          # Path relative to app root (where rake/puma runs from)
          yaml_path = File.expand_path('bin/journals.yml', Dir.pwd)
          
          unless File.file?(yaml_path)
            standard_response(:ok, 'Journals retrieved successfully', { domains: [] })
          end

          raw = File.read(yaml_path)
          data = YAML.safe_load(raw, permitted_classes: [], permitted_symbols: [], aliases: true) || {}

          domains_hash = data.is_a?(Hash) ? (data['domains'] || {}) : {}
          domains_out = []

          build_node = lambda do |key, node|
            node ||= {}
            label = node['label'] || node[:label] || key.to_s

            jlist = Array(node['journals'] || node[:journals]).map do |j|
              j.is_a?(Hash) ? (j['name'] || j[:name]) : j
            end.compact.map { |x| x.to_s.strip }.reject(&:empty?).uniq.sort

            sub_hash = node['subdomains'] || node[:subdomains] || {}
            subs = []
            if sub_hash.is_a?(Hash)
              sub_hash.each do |sub_key, sub_node|
                subs << build_node.call(sub_key, sub_node)
              end
            end

            {
              key: key.to_s,
              label: label.to_s,
              journals: jlist,
              subdomains: subs.sort_by { |h| h[:label].to_s.downcase }
            }
          end

          if domains_hash.is_a?(Hash)
            domains_hash.each do |key, node|
              domains_out << build_node.call(key, node)
            end
          end

          domains_out.sort_by! { |h| h[:label].to_s.downcase }

          standard_response(:ok, 'Journals retrieved successfully', { domains: domains_out })
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
    end
  end
end
