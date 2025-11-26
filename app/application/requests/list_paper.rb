# frozen_string_literal: true

require_relative 'base'

module AcaRadar
  module Request
    # class for listing papers from 2 different journals
    class ListPapers < Base
      VALID_JOURNALS = [
        'MIS Quarterly',
        'Management Science',
        'Journal of the ACM'
      ].freeze

      def journals
        @journals ||= begin
          if params['journal1'] && params['journal2']
            [params['journal1'], params['journal2']].map(&:strip).reject(&:empty?)
          else
            raw = params['journals'] || []
            values = raw.is_a?(Array) ? raw : raw.to_s.split(',')
            values.map(&:to_s).map(&:strip).reject(&:empty?).uniq
          end
        end
      end

      def page
        [params['page'].to_i, 1].max
      end

      def offset(default_per_page = 10)
        (page - 1) * default_per_page
      end

      def valid?
        # Must have exactly 2 journals
        return false unless journals.size == 2
        
        # Must be different
        return false unless journals.uniq.size == 2
        
        # Must be valid journals
        return false unless journals.all? { |j| VALID_JOURNALS.include?(j) }
        
        true
      end

      def error_message
        return 'Page must be a positive integer' if page < 1
        return 'You must select exactly two journals' if journals.size != 2
        return 'Please select two different journals' if journals.uniq.size < 2
        return 'Invalid or unknown journals. Please use one of the allowed journals.' unless journals.all? { |j| VALID_JOURNALS.include?(j) }
        nil
      end
    end
  end
end