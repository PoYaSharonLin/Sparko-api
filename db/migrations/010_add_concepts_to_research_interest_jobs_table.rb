# frozen_string_literal: true

Sequel.migration do
    change do
      alter_table(:research_interest_jobs) do
        add_column :concepts_json, String, text: true
      end
    end
  end
  