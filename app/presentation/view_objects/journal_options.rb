# frozen_string_literal: true

module AcaRadar
  module View
    # class for presenting the journal options in frontend
    class JournalOption
      def all
        [
          ['MIS Quarterly', 'MIS Quarterly'],
          ['Management Science', 'Management Science'],
          ['Journal of the ACM', 'Journal of the ACM']
        ]
      end
    end
  end
end
