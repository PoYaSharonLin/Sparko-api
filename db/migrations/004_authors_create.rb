# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:authors) do
      primary_key :author_id

      String :name
      String :first_name
      String :last_name
    end
  end
end
