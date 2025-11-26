# frozen_string_literal: true

require_relative '../../application/services/calculate_similarity'
require 'roar/decorator'
require 'roar/json'

module AcaRadar
  module Representer
    # class that represents a paper
    class Paper < Representer::Base
      property :origin_id
      property :title
      property :summary, as: :abstract
      property :pdf_url
      property :published_at, exec_context: :decorator
      property :primary_category, as: :category

      property :authors, exec_context: :decorator

      property :similarity_score,
               exec_context: :decorator,
               render_nil: true

      def published_at
        represented.published_at.iso8601
      end

      def authors
        represented.authors.join(', ')
      end

      def similarity_score(options = {})
        user_vector = options[:user_vector_2d]
        return nil unless user_vector || represented.embedding_2d.nil?

        Service::CalculateSimilarity.score(
          user_vector,
          represented.embedding_2d
        )&.round(4)
      end
    end
  end
end
