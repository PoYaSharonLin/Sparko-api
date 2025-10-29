# frozen_string_literal: true

module AcaRadar
  module Database
    # Junction: Paper ↔ Author
    class PaperAuthorOrm < Sequel::Model(:paper_authors)
      many_to_one :paper,
                  class: :'AcaRadar::Database::PaperOrm',
                  key: :paper_id

      many_to_one :author,
                  class: :'AcaRadar::Database::AuthorOrm',
                  key: :author_id

      plugin :timestamps, update_on_create: true

      def self.find_or_create(paper_id:, author_id:)
        first(paper_id: paper_id, author_id: author_id) ||
          create(paper_id: paper_id, author_id: author_id)
      end
    end
  end
end
