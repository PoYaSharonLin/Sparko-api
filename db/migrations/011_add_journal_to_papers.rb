# frozen_string_literal: true

Sequel.migration do
    change do
      alter_table(:papers) do
        add_column :journal, String
        add_index :journal
      end
    end
  end
  