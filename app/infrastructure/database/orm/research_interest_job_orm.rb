# frozen_string_literal: true

module Sparko
  module Database
    # ORM for research interest embedding jobs
    class ResearchInterestJobOrm < Sequel::Model(:research_interest_jobs)
      plugin :timestamps, update_on_create: true

      # If Sequel security plugins are enabled globally, primary key assignment is blocked by default.
      # This allows us to create rows with our UUID primary key (job_id).
      unrestrict_primary_key if respond_to?(:unrestrict_primary_key)

      # If whitelist_security is enabled globally, ONLY allowed columns can be mass-assigned.
      # Ensure all columns you pass in Repository::ResearchInterestJob are allowed.
      if respond_to?(:set_allowed_columns)
        set_allowed_columns :job_id, :term, :status, :error_message, :vector_x, :vector_y,
                    :embedding_b64, :embedding_dim, :created_at, :updated_at
      end
    end
  end
end
