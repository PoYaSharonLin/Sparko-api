# frozen_string_literal: true

module Sparko
  module Database
    # Object-Relational Mapper for Papers
    class PaperOrm < Sequel::Model(:papers)
      set_primary_key :paper_id
      one_to_many :paper_authors,
                  class: :'Sparko::Database::PaperAuthorOrm',
                  key: :paper_id

      one_to_many :paper_categories,
                  class: :'Sparko::Database::PaperCategoryOrm',
                  key: :paper_id

      many_to_many :authors,
                   class: :'Sparko::Database::AuthorOrm',
                   join_table: :paper_authors,
                   left_key: :paper_id,
                   right_key: :author_id

      many_to_many :categories,
                   class: :'Sparko::Database::CategoryOrm',
                   join_table: :paper_categories,
                   left_key: :paper_id,
                   right_key: :category_id

      plugin :timestamps, update_on_create: true
    end
  end
end
