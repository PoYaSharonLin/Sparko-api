# frozen_string_literal: true

require 'dry/monads'
require_relative '../../infrastructure/utilities/logger'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
module AcaRadar
  module Service
    # Service to embed a research interest term
    class EmbedResearchInterest
      include Dry::Monads::Result::Mixin

      def call(term:, request_id:)
        publisher = Messaging::Publisher.new(AcaRadar::App.config, request_id.to_s)
        publisher.publish(status: 'processing', message: 'Extracting concepts', percent: 35)
        sleep(1)
        concepts = Entity::Concept.extract_from(term)
        return Failure('No concepts extracted from research interest') if concepts.empty?

        publisher.publish(status: 'processing', message: 'Extracting concepts', percent: 40)
        sleep(1)

        concepts_array = concepts.map(&:to_s) #array of concepts
        concept_text = concepts.map(&:to_s).join(', ')
        embedding = Value::Embedding.embed_from(concept_text)
        publisher.publish(status: 'processing', message: 'Calculating embeddings', percent: 50)

        two_dim_embedding = Value::TwoDimEmbedding.reduce_dimension_from(embedding.full_embedding)
        publisher.publish(status: 'processing', message: 'Reducing embeddings', percent: 75)
        sleep(1)
        publisher.publish(
          status: 'complete',
          message: 'Analysis done',
          percent: 100,
          payload: { vector_2d: two_dim_embedding.two_dim_embedding, concepts: concepts_array }
        )
        AcaRadar.logger.debug("RI raw term: #{term.inspect}")
        AcaRadar.logger.debug("RI concepts: #{concepts.map(&:to_s).inspect}")
        AcaRadar.logger.debug("RI concept_text: #{concept_text.inspect}")
        AcaRadar.logger.debug("RI emb dims: #{embedding.full_embedding.length}")

        Success(
          term: term,
          embedding: embedding.full_embedding,
          vector_2d: two_dim_embedding.two_dim_embedding,
          concepts: concepts_array
        )
      rescue StandardError => e
        Failure("Failed to embed research interest on channel #{request_id}: #{e.message}")
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
