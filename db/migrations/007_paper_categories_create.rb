# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:paper_categories) do
      foreign_key :paper_id, :papers,
                  null: false,
                  on_delete: :cascade

      foreign_key :category_id, :categories,
                  null: false,
                  on_delete: :cascade

      primary_key %i[paper_id category_id]
    end

    add_index :paper_categories, :paper_id
    add_index :paper_categories, :category_id
  end
end
