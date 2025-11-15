# frozen_string_literal: true

module AcaRadar
  module View
    # View object for presenting a paper in the frontend
    class Paper
      def initialize(entity)
        @entity = entity
      end

      def title
        @entity.title
      end

      def published
        @entity.published
      end

      def authors_list
        @entity.authors.map(&:name).join(', ')
      end

      def short_summary
        @entity.short_summary
      end

      def concepts_list
        @entity.concepts.join(', ')
      end

      def short_embedding
        return '' unless @entity.embedding

        "#{@entity.embedding.take(10).join(', ')}..."
      end

      def two_dim_embedding
        @entity.two_dim_embedding
      end

      # def pdf_href
      #   pdf_link = @entity.links&.find { |link| link.title == 'pdf' }
      #   pdf_link&.href
      # end
    end
  end
end
