# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/vcr_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'
require 'json'

def app
  Sparko::App
end

describe 'iOS-Friendly API Design (A3)' do
  include Rack::Test::Methods

  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr
    DatabaseHelper.wipe_database
  end

  after do
    VcrHelper.eject_vcr
  end

  def parsed_response
    JSON.parse(last_response.body)
  end

  # ────────── Existing Endpoints: Envelope Structure ──────────

  describe 'standard_response JSON envelope' do
    it 'HAPPY: root route returns { status, message } envelope' do
      get '/'

      _(last_response.status).must_equal 200
      body = parsed_response

      _(body).must_include 'status'
      _(body).must_include 'message'
      _(body['status']).must_equal 'ok'
    end

    it 'HAPPY: all responses use Content-Type application/json' do
      get '/'
      _(last_response.content_type).must_include 'application/json'
    end
  end

  # ────────── Existing Endpoints: Cache Headers ──────────

  describe 'HTTP cache headers on papers endpoint' do
    it 'HAPPY: papers endpoint returns Cache-Control and ETag headers' do
      req = Object.new
      req.define_singleton_method(:valid?) { true }
      req.define_singleton_method(:journals) { ['MIS Quarterly'] }
      req.define_singleton_method(:page) { 1 }
      req.define_singleton_method(:min_date) { nil }
      req.define_singleton_method(:max_date) { nil }
      req.define_singleton_method(:error_message) { nil }

      job = OpenStruct.new(
        job_id: 'jid', status: 'completed',
        term: 'test', vector_x: 0.0, vector_y: 0.0,
        embedding_b64: ''
      )

      list_service = Object.new
      list_service.extend(Dry::Monads[:result])
      list_service.define_singleton_method(:call) do |**_kwargs|
        list = OpenStruct.new(
          papers: [],
          pagination: { mode: 'paged', current: 1, total_pages: 0,
                        total_count: 0, prev_page: nil, next_page: nil }
        )
        Dry::Monads::Result::Success.new(list)
      end

      Sparko::Request::ListPapers.stub :new, ->(*) { req } do
        Sparko::Repository::ResearchInterestJob.stub :find, job do
          Sparko::Service::ListPapers.stub :new, ->(*) { list_service } do
            get '/api/v1/papers?request_id=jid'

            _(last_response.status).must_equal 200
            _(last_response.headers['Cache-Control']).wont_be_nil
            _(last_response.headers['Cache-Control']).must_include 'private'
            _(last_response.headers['Cache-Control']).must_include 'max-age'
            _(last_response.headers['ETag']).wont_be_nil
            _(last_response.headers['Vary']).must_equal 'Cookie'
          end
        end
      end
    end
  end

  # ────────── Existing Endpoints: snake_case Keys ──────────

  describe 'snake_case response keys' do
    it 'HAPPY: research_interest status uses snake_case keys' do
      job = OpenStruct.new(
        job_id: 'jid', status: 'completed',
        term: 'machine learning',
        vector_x: 0.5, vector_y: -0.3,
        concepts_json: '["ai"]',
        embedding_dim: 2,
        updated_at: Time.now
      )

      Sparko::Repository::ResearchInterestJob.stub :find, job do
        get '/api/v1/research_interest/jid'

        _(last_response.status).must_equal 200
        body = parsed_response

        # All keys should be snake_case (no camelCase like vectorX, jobId)
        json_str = last_response.body
        _(json_str).wont_include 'jobId'
        _(json_str).wont_include 'vectorX'
        _(json_str).wont_include 'vectorY'

        # Verify actual snake_case keys
        _(body.dig('data', 'job_id')).must_equal 'jid'
        _(body.dig('data', 'vector_2d')).must_equal [0.5, -0.3]
      end
    end

    it 'HAPPY: journals endpoint uses snake_case keys' do
      get '/api/v1/journals'
      _(last_response.status).must_equal 200

      json_str = last_response.body
      _(json_str).wont_include 'statusCode'
      _(json_str).wont_include 'responseData'
    end
  end

  # ────────── ApiResponse: iOS-Specific Envelope ──────────

  describe 'ApiResponse iOS envelope (used by ios_response method)' do
    it 'HAPPY: ApiResponse includes meta.timestamp in ISO 8601' do
      resp = Sparko::Response::ApiResponse.ok('Test', { value: 1 })
      body = JSON.parse(resp.to_json)

      _(body['meta']).wont_be_nil
      _(body['meta']['timestamp']).wont_be_nil

      # Verify it is valid ISO 8601
      ts = body['meta']['timestamp']
      parsed_time = Time.iso8601(ts)
      _(parsed_time).must_be_kind_of Time
    end

    it 'HAPPY: ApiResponse serializes nested dates as ISO 8601' do
      paper_data = {
        title: 'Deep Learning',
        published_at: Time.utc(2025, 3, 15, 10, 0, 0),
        updated_at: Time.utc(2025, 3, 16, 14, 30, 0)
      }
      resp = Sparko::Response::ApiResponse.ok('Paper found', paper_data)
      body = JSON.parse(resp.to_json)

      _(body['data']['published_at']).must_equal '2025-03-15T10:00:00Z'
      _(body['data']['updated_at']).must_equal '2025-03-16T14:30:00Z'
    end

    it 'HAPPY: ApiResponse preserves code field for Swift decoding' do
      resp = Sparko::Response::ApiResponse.ok('Good')
      body = JSON.parse(resp.to_json)

      _(body['code']).must_equal 200
      _(body['code']).must_be_kind_of Integer
    end
  end
end
