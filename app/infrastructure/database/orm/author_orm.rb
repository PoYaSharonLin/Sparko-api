# frozen_string_literal: true

module Sparko
  module Database
    # Object-Relational Mapper for Authors
    class AuthorOrm < Sequel::Model(:authors)
      one_to_many :paper_authors,
                  class: :'Sparko::Database::PaperAuthorOrm',
                  key: :author_id

      many_to_many :papers,
                   class: :'Sparko::Database::PaperOrm',
                   join_table: :paper_authors,
                   left_key: :author_id,
                   right_key: :paper_id

      plugin :timestamps, update_on_create: true

      def self.find_or_create(info)
        first(name: info[:name]) || create(info)
      end
    end
  end
end
