# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/vcr_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'
require 'dry/monads'
require 'json'
require 'base64'

# rubocop:disable Lint/UnusedBlockArgument
def app
  AcaRadar::App
end

describe 'Test AcaRadar API v1 routes' do
  include Rack::Test::Methods
  include Dry::Monads[:result]

  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr
    DatabaseHelper.wipe_database
  end

  after do
    VcrHelper.eject_vcr
  end

  def set_session(data = {})
    session_data = Marshal.dump(data)
    cookie = Base64.strict_encode64(session_data)
    header 'Cookie', "rack.session=#{cookie}"
  end

  def parsed_response
    JSON.parse(last_response.body)
  end

  describe 'Root route' do
    it 'should successfully return API welcome message' do
      get '/'
      _(last_response.status).must_equal 200

      body = parsed_response
      _(body['status']).must_equal 'ok'
      _(body['message']).must_include 'AcaRadar API v1'
      _(body['data']).must_be_nil
    end
  end

  describe 'POST /api/v1/research_interest' do
    valid_term = 'information systems'
    invalid_term = ''
    vector_2d = [0.75, -0.31]

    it 'HAPPY: should successfully embed a valid research interest' do
      stub_service = Object.new
      stub_service.extend(Dry::Monads[:result]) # Extend the stub with Dry::Monads
      stub_service.define_singleton_method(:call) do |term:|
        Success(vector_2d)
      end

      AcaRadar::Service::EmbedResearchInterest.stub :new, ->(*) { stub_service } do
        post '/api/v1/research_interest',
             { term: valid_term }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }

        _(last_response.status).must_equal 202
        body = parsed_response

        _(body['status']).must_equal 'processing'
      end
    end

    it 'SAD: should reject empty or invalid term' do
      post '/api/v1/research_interest',
           { term: '' }.to_json,
           { 'CONTENT_TYPE' => 'application/json' }

      _(last_response.status).must_equal 400
      body = parsed_response

      _(body['status']).must_equal 'bad_request'
      _(body['message']).must_equal 'Research interest must be a non-empty string'
      _(body['data']).must_be_nil
    end

    it 'SAD: should handle service failure gracefully' do
      failing_service = Object.new
      failing_service.extend(Dry::Monads[:result])
      failing_service.define_singleton_method(:call) do |term:|
        Failure('Embedding model unavailable')
      end

      AcaRadar::Service::EmbedResearchInterest.stub :new, ->(*) { failing_service } do
        post '/api/v1/research_interest',
             { term: invalid_term }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }

        _(last_response.status).must_equal 400
      end
    end
  end

  # worker tests
  describe 'POST /api/v1/research_interest/async' do
    it 'HAPPY: should queue job and return job_id' do
      job_id = 'job_12345'

      queue_service = Object.new
      queue_service.extend(Dry::Monads[:result])
      queue_service.define_singleton_method(:call) do |term:|
        Success(job_id)
      end

      AcaRadar::Service::QueueResearchInterestEmbedding.stub :new, ->(*) { queue_service } do
        post '/api/v1/research_interest/async',
             { term: 'machine learning' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }

        _(last_response.status).must_equal 202
        body = parsed_response

        _(body['status']).must_equal 'processing'
      end
    end
  end
end
# rubocop:enable Lint/UnusedBlockArgument
