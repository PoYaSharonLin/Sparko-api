# frozen_string_literal: true

module AcaRadar
  module Database
    # class for Job orm
    class ResearchInterestJobOrm < Sequel::Model(:research_interest_jobs)
      plugin :timestamps, update_on_create: true
    end
  end
end
