# frozen_string_literal: true

require 'dry-monads'

module AcaRadar
  module Service
    # Service to embed a research interest term
    class EmbedResearchInterest
      include Dry::Monads::Result::Mixin

      def call(input)
        research_interest = input[:single_term]
        begin
          # Embed the research interest directly (as a single term)
          embedding = Value::Embedding.embed_from(research_interest)
          two_dim_embedding = Value::TwoDimEmbedding.reduce_dimension_from(embedding.full_embedding)
          Success(two_dim_embedding.two_dim_embedding)
        rescue StandardError => e
          Failure("Failed to embed research interest: #{e.message}")
        end
      end
    end
  end
end
