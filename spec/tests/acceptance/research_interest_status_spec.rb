# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/vcr_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'
require 'dry/monads'
require 'json'
require 'time'

# rubocop:disable Lint/UnusedBlockArgument
def app
  AcaRadar::App
end

describe 'GET /api/v1/research_interest/:job_id' do
  include Rack::Test::Methods
  include Dry::Monads[:result]

  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr
    DatabaseHelper.wipe_database
    AcaRadar::Database::ResearchInterestJobOrm.dataset.delete if defined?(AcaRadar::Database::ResearchInterestJobOrm)
  end

  after do
    VcrHelper.eject_vcr
  end

  def parsed_response
    JSON.parse(last_response.body)
  end

  it 'SAD: returns 404 when job is missing' do
    AcaRadar::Repository::ResearchInterestJob.stub :find, nil do
      get '/api/v1/research_interest/nope'
      _(last_response.status).must_equal 404

      body = parsed_response
      _(body['status']).must_equal 'not_found'
      _(body['message']).must_equal 'Job not found'
    end
  end

  it 'HAPPY: returns 202 when job is processing' do
    job = OpenStruct.new(job_id: 'jid', status: 'processing', updated_at: Time.now)

    AcaRadar::Repository::ResearchInterestJob.stub :find, job do
      get '/api/v1/research_interest/jid'
      _(last_response.status).must_equal 202

      body = parsed_response
      _(body['status']).must_equal 'processing'
      _(body.dig('data', 'status')).must_equal 'processing'
      _(body.dig('data', 'job_id')).must_equal 'jid'
    end
  end

  it 'HAPPY: returns 200 + concepts when job is completed' do
    job = OpenStruct.new(
      job_id: 'jid',
      status: 'completed',
      term: 'machine learning',
      vector_x: 0.1,
      vector_y: 0.2,
      concepts_json: '["a","b"]',
      embedding_dim: 2,
      updated_at: Time.now
    )

    AcaRadar::Repository::ResearchInterestJob.stub :find, job do
      get '/api/v1/research_interest/jid'
      _(last_response.status).must_equal 200

      body = parsed_response
      _(body['status']).must_equal 'ok'
      _(body.dig('data', 'status')).must_equal 'completed'
      _(body.dig('data', 'term')).must_equal 'machine learning'
      _(body.dig('data', 'vector_2d')).must_equal [0.1, 0.2]
      _(body.dig('data', 'concepts')).must_equal %w[a b]
    end
  end

  it 'SAD: bad concepts_json is handled gracefully (concepts => [])' do
    job = OpenStruct.new(
      job_id: 'jid',
      status: 'completed',
      term: 'machine learning',
      vector_x: 0.1,
      vector_y: 0.2,
      concepts_json: '{not json',
      embedding_dim: 2,
      updated_at: Time.now
    )

    AcaRadar::Repository::ResearchInterestJob.stub :find, job do
      get '/api/v1/research_interest/jid'
      _(last_response.status).must_equal 200

      body = parsed_response
      _(body.dig('data', 'concepts')).must_equal []
    end
  end

  it 'HAPPY: supports ETag polling (returns 304 when unchanged)' do
    job = OpenStruct.new(
      job_id: 'jid',
      status: 'processing',
      updated_at: Time.parse('2025-01-01T00:00:00Z'),
      vector_x: nil,
      vector_y: nil,
      embedding_dim: 0
    )

    AcaRadar::Repository::ResearchInterestJob.stub :find, job do
      get '/api/v1/research_interest/jid'
      _(last_response.status).must_equal 202

      etag = last_response.headers['ETag']
      _(etag).wont_be_nil

      header 'If-None-Match', etag
      get '/api/v1/research_interest/jid'
      _(last_response.status).must_equal 304

      body = parsed_response
      _(body['status']).must_equal 'not_modified'
      _(body['message']).must_equal 'Not Modified'
    end
  end
end
# rubocop:enable Lint/UnusedBlockArgument
