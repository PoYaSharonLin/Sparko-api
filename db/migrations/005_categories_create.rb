# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:categories) do
      primary_key :category_id

      String :arxiv_name
      String :display_name
    end
  end
end
