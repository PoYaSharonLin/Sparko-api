# frozen_string_literal: true

require 'dry/monads'
require 'ostruct'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
module AcaRadar
  module Service
    # class for processing papers from repository and pagination
    class ListPapers
      include Dry::Monads::Result::Mixin

      PER_PAGE = 10

      def call(journals:, page:)
        page     = [page.to_i, 1].max
        per_page = PER_PAGE
        offset   = (page - 1) * per_page

        papers = AcaRadar::Repository::Paper.find_by_categories(
          journals,
          limit: per_page,
          offset: offset
        )
        total = AcaRadar::Repository::Paper.count_by_categories(journals)

        total_pages = (total.to_f / per_page).ceil

        result_obj = OpenStruct.new(
          papers: papers,
          pagination: {
            current: page,
            total_pages: total_pages,
            total_count: total,
            prev_page: page > 1 ? page - 1 : nil,
            next_page: page < total_pages ? page + 1 : nil
          }
        )

        Success(result_obj)
      rescue StandardError => e
        AcaRadar::App::APP_LOGGER.error(
          "Service::ListPapers failed: #{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
        )
        Failure(e)
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
