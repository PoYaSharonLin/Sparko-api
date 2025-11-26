# frozen_string_literal: true

require_relative '../config/environment'
require_relative '../app/infrastructure/arxiv/gateways/arxiv_api'
require_relative '../app/presentation/view_objects/journal_options'
require_relative '../app/models/entities/summary'
require_relative '../app/domain/clustering/entities/query'
require_relative '../app/domain/clustering/entities/papers'
require_relative '../app/domain/clustering/entities/concepts'
require_relative '../app/domain/clustering/values/embedding'
require_relative '../app/domain/clustering/values/two_dim_embedding'
require_relative '../app/infrastructure/database/repositories/papers'

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
module AcaRadar
  # Fetch data from api call and store in db
  class ArxivFetcher
    def initialize
      @api = ArXivApi.new
      @journals = View::JournalOption.all
    end

    def run
      @journals.each do |journal|
        query = Query.new(journals: [journal[0]])
        fetch_and_process(query)
        sleep 5 # respect rate limit
      end
      puts 'Fetched and processed papers for all journals.'
    end

    private

    def fetch_and_process(query)
      api_response = @api.call(query)
      return unless api_response.ok?

      api_response.papers.each do |paper|
        begin
          # pre-compute everything
          concepts = Entity::Concept.extract_from(paper.summary.full_summary)
          embedding = Value::Embedding.embed_from(concepts.map(&:to_s).join(', '))
          two_dim_embedding = Value::TwoDimEmbedding.reduce_dimension_from(embedding.full_embedding)

          # store pre-computed fields
          Repository::Paper.create_or_update(
            origin_id: paper.origin_id,
            title: paper.title,
            published: paper.published,
            authors: paper.authors,
            summary: paper.summary.full_summary,
            short_summary: paper.summary.short_summary,
            concepts: concepts.map(&:to_s),
            embedding: embedding.full_embedding,
            two_dim_embedding: two_dim_embedding.two_dim_embedding,
            categories: paper.categories,
            links: paper.links,
            fetched_at: Time.now
          )
        end
      rescue StandardError => e
        puts "Error processing paper #{paper.origin_id}: #{e.message}. Skipping paper."
      end
    rescue StandardError => e
      puts "Error fetching for arXiv api: #{e.message}. Skipping."
    end
  end
end

AcaRadar::ArxivFetcher.new.run
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
