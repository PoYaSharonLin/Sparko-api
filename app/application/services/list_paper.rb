# frozen_string_literal: true

require 'dry/monads'
require 'ostruct'
require_relative '../../infrastructure/utilities/logger'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
module Sparko
  module Service
    class ListPapers
      include Dry::Monads::Result::Mixin

      PER_PAGE  = 25
      MAX_FETCH = 10000
      MAX_TOP_N = 50

      # If top_n is provided (>0), returns top_n closest papers (no paging).
      # Otherwise returns a normal paged slice (PER_PAGE) from the sorted list.
      def call(journals:, page:, research_embedding: nil, top_n: nil, min_date: nil, max_date: nil)
        page     = [page.to_i, 1].max
        per_page = PER_PAGE

        top_n_i = parse_top_n(top_n)

        Sparko.logger.debug(
          "ListPapers: journals=#{journals.inspect} page=#{page} top_n=#{top_n_i.inspect} " \
          "min_date=#{min_date.inspect} max_date=#{max_date.inspect} " \
          "research_embedding_class=#{research_embedding.class} len=#{research_embedding&.length}"
        )

        # Fetch candidate papers from DB (filtered by journals and date range)
        all_papers = Sparko::Repository::Paper.find_by_categories(
          journals,
          limit: MAX_FETCH,
          offset: 0,
          min_date: min_date,
          max_date: max_date
        )

        total       = all_papers.length
        total_pages = (total.to_f / per_page).ceil

        # If we have a valid research embedding, compute scores and sort by similarity desc
        if valid_research_embedding?(research_embedding)
          research = research_embedding.map(&:to_f)
          dim = research.length

          computed = 0
          skipped_empty = 0
          skipped_dim = 0
          skipped_nonfinite = 0
          skipped_zero = 0

          skipped_samples = { empty: [], dim: [], nonfinite: [], zero: [] }

          all_papers.each do |paper|
            emb = paper.embedding
            paper.similarity_score = nil

            unless emb.is_a?(Array) && !emb.empty?
              skipped_empty += 1
              skipped_samples[:empty] << paper.title if skipped_samples[:empty].length < 3
              next
            end

            if emb.length != dim
              skipped_dim += 1
              skipped_samples[:dim] << "#{paper.title} (paper_dim=#{emb.length}, ri_dim=#{dim})" if skipped_samples[:dim].length < 3
              next
            end

            emb_f = emb.map(&:to_f)
            unless all_finite?(emb_f)
              skipped_nonfinite += 1
              skipped_samples[:nonfinite] << paper.title if skipped_samples[:nonfinite].length < 3
              next
            end

            if vector_norm(emb_f).zero? || vector_norm(research).zero?
              skipped_zero += 1
              skipped_samples[:zero] << paper.title if skipped_samples[:zero].length < 3
              next
            end

            score = Sparko::Service::CalculateSimilarity.score(research, emb_f)

            if score.nil? || !score.finite?
              skipped_nonfinite += 1
              skipped_samples[:nonfinite] << "#{paper.title} (score=#{score.inspect})" if skipped_samples[:nonfinite].length < 3
              next
            end

            paper.similarity_score = score.to_f
            computed += 1
          end

          all_papers.sort_by! { |p| -(p.similarity_score || -1.0) }

          top5 = all_papers.first(5).map { |p| [p.title, p.similarity_score] }
          Sparko.logger.debug(
            "ListPapers: similarity computed=#{computed}/#{total} " \
            "skipped_empty=#{skipped_empty} skipped_dim=#{skipped_dim} " \
            "skipped_nonfinite=#{skipped_nonfinite} skipped_zero=#{skipped_zero}"
          )
          Sparko.logger.debug("ListPapers: Top 5 scores: #{top5.inspect}")
          if skipped_empty.positive? || skipped_dim.positive? || skipped_nonfinite.positive? || skipped_zero.positive?
            Sparko.logger.debug("ListPapers: skipped samples #{skipped_samples.inspect}")
          end
        else
          Sparko.logger.debug("ListPapers: no usable research embedding; similarity_score will be nil")
          all_papers.each { |p| p.similarity_score = nil if p.respond_to?(:similarity_score=) }
        end

        papers, pagination =
          if top_n_i
            [
              all_papers.first(top_n_i) || [],
              {
                mode: 'top_n',
                top_n: top_n_i,
                current: 1,
                total_pages: 1,
                total_count: total,
                prev_page: nil,
                next_page: nil
              }
            ]
          else
            offset = (page - 1) * per_page
            [
              all_papers.slice(offset, per_page) || [],
              {
                mode: 'paged',
                current: page,
                total_pages: total_pages,
                total_count: total,
                prev_page: page > 1 ? page - 1 : nil,
                next_page: page < total_pages ? page + 1 : nil
              }
            ]
          end

        Success(OpenStruct.new(papers: papers, pagination: pagination))
      rescue StandardError => e
        Sparko.logger.error(
          "Service::ListPapers failed: #{e.class} - #{e.message}\n#{e.backtrace&.first(12)&.join("\n")}"
        )
        Failure(e)
      end

      private

      def parse_top_n(raw)
        return nil if raw.nil?

        s = raw.to_s.strip
        return nil if s.empty?
        return nil unless s.match?(/\A[1-9]\d*\z/)

        n = s.to_i
        n = [n, MAX_TOP_N].min
        n
      end

      def valid_research_embedding?(vec)
        vec.is_a?(Array) &&
          !vec.empty? &&
          vec.all? { |x| numeric_like?(x) } &&
          all_finite?(vec.map(&:to_f))
      rescue StandardError
        false
      end

      def numeric_like?(x)
        Float(x)
        true
      rescue StandardError
        false
      end

      def all_finite?(arr)
        arr.all? { |x| x.is_a?(Numeric) && x.finite? }
      end

      def vector_norm(arr)
        sum_sq = 0.0
        arr.each do |v|
          f = v.to_f
          sum_sq += f * f
        end
        Math.sqrt(sum_sq)
      rescue StandardError
        0.0
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
