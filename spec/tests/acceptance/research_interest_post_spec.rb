# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/vcr_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'
require 'dry/monads'
require 'json'
require 'base64'
require 'securerandom'

# rubocop:disable Lint/UnusedBlockArgument
def app
  Sparko::App
end

describe 'POST /api/v1/research_interest (+ /async)' do
  include Rack::Test::Methods
  include Dry::Monads[:result]

  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr
    DatabaseHelper.wipe_database
    Sparko::Database::ResearchInterestJobOrm.dataset.delete if defined?(Sparko::Database::ResearchInterestJobOrm)
  end

  after do
    VcrHelper.eject_vcr
  end

  def parsed_response
    JSON.parse(last_response.body)
  end

  describe 'POST /api/v1/research_interest' do
    it 'HAPPY: queues job and returns 202 + status_url' do
      job_id = 'job_12345'

      queue_service = Object.new
      queue_service.extend(Dry::Monads[:result])
      queue_service.define_singleton_method(:call) { |term:| Success(job_id) }

      fake_job = OpenStruct.new(job_id: job_id, status: 'queued')

      Sparko::Service::QueueResearchInterestEmbedding.stub :new, ->(*) { queue_service } do
        Sparko::Repository::ResearchInterestJob.stub :find, fake_job do
          post '/api/v1/research_interest',
               { term: 'machine learning' }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }

          _(last_response.status).must_equal 202
          body = parsed_response

          _(body['status']).must_equal 'processing'
          _(body.dig('data', 'request_id')).must_equal job_id
          _(body.dig('data', 'status_url')).must_equal "/api/v1/research_interest/#{job_id}"
        end
      end
    end

    it 'SAD: rejects empty term' do
      post '/api/v1/research_interest',
           { term: '' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      _(last_response.status).must_equal 400
      body = parsed_response

      _(body['status']).must_equal 'bad_request'
      _(body['message']).must_equal 'Research interest cannot be empty.'
      _(body['data']).wont_be_nil
      _(body.dig('data', 'error_code')).must_equal 'empty'
    end

    it 'HAPPY: returns cached completed job immediately (200)' do
      job_id = 'job_cached_1'

      queue_service = Object.new
      queue_service.extend(Dry::Monads[:result])
      queue_service.define_singleton_method(:call) { |term:| Success(job_id) }

      completed_job = OpenStruct.new(
        job_id: job_id,
        status: 'completed',
        term: 'machine learning',
        vector_x: 0.12,
        vector_y: -0.34,
        concepts_json: '["topic_a","topic_b"]',
        embedding_b64: ''
      )

      Sparko::Service::QueueResearchInterestEmbedding.stub :new, ->(*) { queue_service } do
        Sparko::Repository::ResearchInterestJob.stub :find, completed_job do
          post '/api/v1/research_interest',
               { term: 'machine learning' }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }

          _(last_response.status).must_equal 200
          body = parsed_response

          _(body['status']).must_equal 'ok'
          _(body.dig('data', 'cached')).must_equal true
          _(body.dig('data', 'status')).must_equal 'completed'
          _(body.dig('data', 'request_id')).must_equal job_id
          _(body.dig('data', 'vector_2d')).must_equal [0.12, -0.34]
          _(body.dig('data', 'concepts')).must_equal %w[topic_a topic_b]
        end
      end
    end
  end

  describe 'POST /api/v1/research_interest/async' do
    it 'HAPPY: queues job and returns 202' do
      job_id = 'job_async_123'

      queue_service = Object.new
      queue_service.extend(Dry::Monads[:result])
      queue_service.define_singleton_method(:call) { |term:| Success(job_id) }

      Sparko::Service::QueueResearchInterestEmbedding.stub :new, ->(*) { queue_service } do
        post '/api/v1/research_interest/async',
             { term: 'machine learning' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }

        _(last_response.status).must_equal 202
        body = parsed_response

        _(body['status']).must_equal 'processing'
        returned_id = body.dig('data', 'job_id') || body.dig('data', 'request_id')
        _(returned_id).must_equal job_id
        _(body.dig('data', 'status_url')).must_equal "/api/v1/research_interest/#{returned_id}"
      end
    end

    it 'SAD: rejects invalid term (non-string)' do
      post '/api/v1/research_interest/async',
           { term: 123 }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      _(last_response.status).must_equal 400
      body = parsed_response
      _(body['status']).must_equal 'bad_request'
      _(body['message']).must_equal 'Research interest must be a string.'
    end

    it 'HAPPY: cache hit returns 200 without queueing' do
      # Insert completed cached job that /async cache lookup will find
      job_id = 'job_db_cached'
      now = Time.now

      Sparko::Database::ResearchInterestJobOrm.create(
        job_id: job_id,
        term: 'machine learning', # normalized stored
        status: 'completed',
        vector_x: 1.0,
        vector_y: 2.0,
        concepts_json: '[]',
        embedding_b64: 'abc',
        embedding_dim: 3,
        created_at: now,
        updated_at: now
      )

      post '/api/v1/research_interest/async',
           { term: '  Machine   Learning ' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      _(last_response.status).must_equal 200
      body = parsed_response

      _(body['status']).must_equal 'ok'
      _(body.dig('data', 'cached')).must_equal true
      _(body.dig('data', 'request_id')).must_equal job_id
      _(body.dig('data', 'status')).must_equal 'completed'
    end
  end
end
# rubocop:enable Lint/UnusedBlockArgument
