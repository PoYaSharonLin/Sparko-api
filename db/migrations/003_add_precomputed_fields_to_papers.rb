# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:papers) do
      add_column :authors, String, default: '[]'
      add_column :short_summary, String, text: true
      add_column :concepts, String, default: '[]'
      add_column :embedding, String, default: '[]'
      add_column :two_dim_embedding, String, default: '[]'
      add_column :categories, String, default: '[]'
      add_column :fetched_at, DateTime
    end
  end
end
