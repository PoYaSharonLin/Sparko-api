# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:paper_authors) do
      foreign_key :paper_id, :papers,
                  null: false,
                  on_delete: :cascade

      foreign_key :author_id, :authors,
                  null: false,
                  on_delete: :cascade

      primary_key %i[paper_id author_id]
    end

    add_index :paper_authors, :paper_id
    add_index :paper_authors, :author_id
  end
end
