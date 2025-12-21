# frozen_string_literal: true

module AcaRadar
  module Repository
    class ResearchInterestJob
      # --- CREATE / FIND ------------------------------------------------------

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

      # Cache lookup: completed job for the same normalized term.
      # Optional: restrict freshness by updated_at.
      def self.find_completed_by_term(term, max_age_seconds: nil)
        ds = Database::ResearchInterestJobOrm.where(
          term: term,
          status: 'completed'
        )

        if max_age_seconds
          cutoff = Time.now - max_age_seconds
          ds = ds.where { updated_at >= cutoff }
        end

        ds.order(Sequel.desc(:updated_at)).first
      end

      # --- STATUS UPDATES -----------------------------------------------------

      def self.try_mark_processing(job_id)
        affected = Database::ResearchInterestJobOrm
          .where(job_id: job_id, status: 'queued')
          .update(status: 'processing', updated_at: Time.now)
      
        affected == 1
      end
      
      def self.mark_processing(job_id)
        update_status(job_id, 'processing')
      end

      # Stores BOTH 2D vector and optional embedding_b64/dim.
      def self.mark_completed(job_id, vector_2d, embedding_b64: nil, embedding_dim: nil, concepts: nil)
        orm = find(job_id)
        return unless orm

        concepts_arr = Array(concepts).map(&:to_s)

        update_hash = {
          status: 'completed',
          vector_x: vector_2d.is_a?(Array) ? vector_2d[0].to_f : nil,
          vector_y: vector_2d.is_a?(Array) ? vector_2d[1].to_f : nil,
          error_message: nil,
          updated_at: Time.now,
          concepts_json: concepts_arr.to_json
        }

        # Only set embedding fields if provided
        if embedding_b64 && !embedding_b64.to_s.empty?
          update_hash[:embedding_b64] = embedding_b64
          update_hash[:embedding_dim] = embedding_dim.to_i if embedding_dim
        end

        orm.update(update_hash)
      end

      def self.mark_failed(job_id, error)
        orm = find(job_id)
        return unless orm

        orm.update(
          status: 'failed',
          updated_at: Time.now,
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
