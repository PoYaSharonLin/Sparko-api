# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:research_interest_jobs) do
      String  :job_id, primary_key: true
      String  :term, null: false
      String  :status, null: false, default: 'queued' # queued, processing, completed, failed
      String  :error_message, text: true
      Float   :vector_x
      Float   :vector_y
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
