# frozen_string_literal: true

require 'dry/monads'

module AcaRadar
  module Service
    # Service to embed a research interest term
    class EmbedResearchInterest
      include Dry::Monads::Result::Mixin

      def call(term:)
        embedding = Value::Embedding.embed_from(term)
        two_dim_embedding = Value::TwoDimEmbedding.reduce_dimension_from(embedding.full_embedding)
        Success(two_dim_embedding.two_dim_embedding)
      rescue StandardError => e
        Failure("Failed to embed research interest: #{e.message}")
      end
    end
  end
end
