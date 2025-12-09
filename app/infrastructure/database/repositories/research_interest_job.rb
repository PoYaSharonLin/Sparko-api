# frozen_string_literal: true

module AcaRadar
  module Repository
    # Repository for ResearchInterestJob
    class ResearchInterestJob
      def self.create(job_id:, term:)
        Database::ResearchInterestJobOrm.create(
          job_id: job_id,
          term: term,
          status: 'queued'
        )
      end

      def self.find(job_id)
        Database::ResearchInterestJobOrm.first(job_id: job_id)
      end

      def self.mark_processing(job_id)
        update_status(job_id, 'processing')
      end

      def self.mark_completed(job_id, vector_2d)
        orm = find(job_id)
        return unless orm

        orm.update(
          status: 'completed',
          vector_x: vector_2d[0],
          vector_y: vector_2d[1],
          error_message: nil
        )
      end

      def self.mark_failed(job_id, error)
        orm = find(job_id)
        return unless orm

        orm.update(
          status: 'failed',
          error_message: error.to_s
        )
      end

      def self.update_status(job_id, status)
        orm = find(job_id)
        return unless orm

        orm.update(status: status)
      end
    end
  end
end
