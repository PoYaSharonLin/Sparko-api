# frozen_string_literal: true

module AcaRadar
  module Database
    # Junction: Paper ↔ Category
    class PaperCategoryOrm < Sequel::Model(:paper_categories)
      many_to_one :paper,
                  class: :'AcaRadar::Database::PaperOrm',
                  key: :paper_id

      many_to_one :category,
                  class: :'AcaRadar::Database::CategoryOrm',
                  key: :category_id

      plugin :timestamps, update_on_create: true

      def self.find_or_create(paper_id:, category_id:)
        first(paper_id: paper_id, category_id: category_id) ||
          create(paper_id: paper_id, category_id: category_id)
      end
    end
  end
end
