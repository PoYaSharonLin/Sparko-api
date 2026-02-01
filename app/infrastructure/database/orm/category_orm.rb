# frozen_string_literal: true

module Sparko
  module Database
    # Object-Relational Mapper for Categories
    class CategoryOrm < Sequel::Model(:categories)
      one_to_many :paper_categories,
                  class: :'Sparko::Database::PaperCategoryOrm',
                  key: :category_id

      many_to_many :papers,
                   class: :'Sparko::Database::PaperOrm',
                   join_table: :paper_categories,
                   left_key: :category_id,
                   right_key: :paper_id

      plugin :timestamps, update_on_create: true

      def self.find_or_create(info)
        first(arxiv_name: info[:arxiv_name]) || create(info)
      end
    end
  end
end
