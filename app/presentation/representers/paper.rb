# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Sparko
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

      # list of keywords / concepts for this paper
      property :concepts,
               exec_context: :decorator,
               render_nil: true

      # 2D embedding of the paper in the same space as research interest
      property :embedding_2d,
               exec_context: :decorator,
               render_nil: true

      property :similarity_score,
               exec_context: :decorator,
               render_nil: true

      def published_at
        represented.published_at.iso8601
      end

      def authors
        Array(represented.authors).map do |a|
          s = a.respond_to?(:name) ? a.name.to_s : a.to_s
      
          # extract whatever is inside the quotes
          if (m = s.match(/\"([^\"]+)\"/))
            m[1]
          else
            s
          end
        end.reject(&:empty?)
      end

      def concepts
        represented.concepts
      end

      def embedding_2d
        vec = represented.two_dim_embedding
        return nil unless vec && vec.size == 2

        {
          x: vec[0].round(6),
          y: vec[1].round(6)
        }
      end

      def similarity_score(*)
        s = represented.respond_to?(:similarity_score) ? represented.similarity_score : nil
        return nil if s.nil?
      
        s.to_f.round(4)
      end      
    end
  end
end
