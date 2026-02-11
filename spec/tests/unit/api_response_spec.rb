# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require 'json'
require 'time'
require 'digest'

describe 'Sparko::Response::ApiResponse' do
  # ────────── JSON Envelope Structure ──────────

  describe 'JSON response envelope' do
    it 'HAPPY: returns { status, code, message, data, meta } envelope' do
      resp = Sparko::Response::ApiResponse.ok('Success', { name: 'test' })
      body = JSON.parse(resp.to_json)

      _(body).must_include 'status'
      _(body).must_include 'code'
      _(body).must_include 'message'
      _(body).must_include 'data'
      _(body).must_include 'meta'
    end

    it 'HAPPY: status field is a string representation of the symbol' do
      resp = Sparko::Response::ApiResponse.ok('Works')
      body = JSON.parse(resp.to_json)

      _(body['status']).must_equal 'ok'
    end

    it 'HAPPY: code field matches HTTP status code' do
      resp = Sparko::Response::ApiResponse.ok('Works')
      _(resp.code).must_equal 200

      resp2 = Sparko::Response::ApiResponse.bad_request('Bad')
      _(resp2.code).must_equal 400

      resp3 = Sparko::Response::ApiResponse.not_found('Missing')
      _(resp3.code).must_equal 404

      resp4 = Sparko::Response::ApiResponse.processing('Working')
      _(resp4.code).must_equal 202

      resp5 = Sparko::Response::ApiResponse.error('Boom')
      _(resp5.code).must_equal 500
    end

    it 'HAPPY: data is absent or empty when no data provided' do
      resp = Sparko::Response::ApiResponse.ok('No data')
      body = JSON.parse(resp.to_json)

      # When nil data is passed, it is either omitted (compact) or empty
      if body.key?('data')
        _(body['data']).must_be_empty
      end
    end

    it 'HAPPY: data passes through when provided' do
      resp = Sparko::Response::ApiResponse.ok('With data', { key: 'value' })
      body = JSON.parse(resp.to_json)

      _(body['data']).must_equal({ 'key' => 'value' })
    end
  end

  # ────────── Meta Field with Timestamp ──────────

  describe 'meta field' do
    it 'HAPPY: always includes an ISO 8601 timestamp in meta' do
      resp = Sparko::Response::ApiResponse.ok('Test')
      body = JSON.parse(resp.to_json)

      _(body['meta']).must_include 'timestamp'
      timestamp = body['meta']['timestamp']

      # Should be parseable as ISO 8601
      parsed = Time.iso8601(timestamp)
      _(parsed).must_be_kind_of Time
    end

    it 'HAPPY: merges custom meta with base timestamp' do
      resp = Sparko::Response::ApiResponse.ok('Test', nil, meta: { page: 1, total: 42 })
      body = JSON.parse(resp.to_json)

      _(body['meta']['timestamp']).wont_be_nil
      _(body['meta']['page']).must_equal 1
      _(body['meta']['total']).must_equal 42
    end
  end

  # ────────── ISO 8601 Date Serialization ──────────

  describe 'ISO 8601 date serialization' do
    it 'HAPPY: converts Time objects to ISO 8601 strings' do
      t = Time.utc(2025, 6, 15, 12, 30, 0)
      resp = Sparko::Response::ApiResponse.ok('Test', { created_at: t })
      body = JSON.parse(resp.to_json)

      _(body['data']['created_at']).must_equal '2025-06-15T12:30:00Z'
    end

    it 'HAPPY: converts Date objects to ISO 8601 strings' do
      d = Date.new(2025, 6, 15)
      resp = Sparko::Response::ApiResponse.ok('Test', { date: d })
      body = JSON.parse(resp.to_json)

      _(body['data']['date']).must_equal '2025-06-15'
    end

    it 'HAPPY: converts DateTime objects to ISO 8601 strings' do
      dt = DateTime.new(2025, 6, 15, 12, 30, 0)
      resp = Sparko::Response::ApiResponse.ok('Test', { datetime: dt })
      body = JSON.parse(resp.to_json)

      _(body['data']['datetime']).must_equal '2025-06-15T12:30:00Z'
    end

    it 'HAPPY: recursively converts dates in nested structures' do
      t = Time.utc(2025, 1, 1, 0, 0, 0)
      data = {
        paper: {
          title: 'Test Paper',
          published_at: t,
          tags: ['ai', 'ml']
        },
        entries: [
          { name: 'A', updated_at: t },
          { name: 'B', updated_at: t }
        ]
      }
      resp = Sparko::Response::ApiResponse.ok('Test', data)
      body = JSON.parse(resp.to_json)

      _(body['data']['paper']['published_at']).must_equal '2025-01-01T00:00:00Z'
      _(body['data']['entries'][0]['updated_at']).must_equal '2025-01-01T00:00:00Z'
      _(body['data']['entries'][1]['updated_at']).must_equal '2025-01-01T00:00:00Z'
      _(body['data']['paper']['tags']).must_equal ['ai', 'ml']
    end
  end

  # ────────── snake_case Keys ──────────

  describe 'snake_case keys' do
    it 'HAPPY: preserves snake_case keys in data' do
      data = { research_interest_term: 'ml', paper_count: 42, two_dim_embedding: [0.1, 0.2] }
      resp = Sparko::Response::ApiResponse.ok('Test', data)
      body = JSON.parse(resp.to_json)

      _(body['data']).must_include 'research_interest_term'
      _(body['data']).must_include 'paper_count'
      _(body['data']).must_include 'two_dim_embedding'
    end

    it 'HAPPY: top-level envelope keys are snake_case' do
      resp = Sparko::Response::ApiResponse.ok('Test', { a: 1 })
      json_str = resp.to_json

      # All keys in the JSON should be lowercase/snake_case (no camelCase)
      _(json_str).wont_include 'statusCode'
      _(json_str).wont_include 'responseData'
      _(json_str).wont_include 'metaData'
    end
  end

  # ────────── Cache Headers ──────────

  describe 'cache headers' do
    it 'HAPPY: apply_cache_headers sets Cache-Control, Vary, and ETag' do
      resp = Sparko::Response::ApiResponse.ok('Cached', { value: 42 })

      fake_headers = {}
      resp.apply_cache_headers(fake_headers, max_age: 300)

      _(fake_headers['Cache-Control']).must_equal 'private, max-age=300'
      _(fake_headers['Vary']).must_equal 'Accept, Accept-Encoding'
      _(fake_headers['ETag']).wont_be_nil
      _(fake_headers['ETag']).must_match(/^"[a-f0-9]{64}"$/)  # SHA256 in quotes
    end

    it 'HAPPY: apply_cache_headers supports public caching' do
      resp = Sparko::Response::ApiResponse.ok('Public')

      fake_headers = {}
      resp.apply_cache_headers(fake_headers, max_age: 60, private_cache: false)

      _(fake_headers['Cache-Control']).must_equal 'public, max-age=60'
    end

    it 'HAPPY: etag is deterministic for the same content' do
      resp1 = Sparko::Response::ApiResponse.ok('Same', { x: 1 })
      resp2 = Sparko::Response::ApiResponse.ok('Same', { x: 1 })

      _(resp1.etag).must_equal resp2.etag
    end

    it 'HAPPY: etag changes when content differs' do
      resp1 = Sparko::Response::ApiResponse.ok('One', { x: 1 })
      resp2 = Sparko::Response::ApiResponse.ok('Two', { x: 2 })

      _(resp1.etag).wont_equal resp2.etag
    end
  end

  # ────────── Factory Methods ──────────

  describe 'factory methods' do
    it 'HAPPY: ApiResponse.ok returns 200' do
      resp = Sparko::Response::ApiResponse.ok('All good')
      _(resp.code).must_equal 200
      _(resp.status).must_equal :ok
    end

    it 'HAPPY: ApiResponse.created returns 201' do
      resp = Sparko::Response::ApiResponse.created('Created')
      _(resp.code).must_equal 201
      _(resp.status).must_equal :created
    end

    it 'HAPPY: ApiResponse.processing returns 202' do
      resp = Sparko::Response::ApiResponse.processing('In progress')
      _(resp.code).must_equal 202
      _(resp.status).must_equal :processing
    end

    it 'HAPPY: ApiResponse.bad_request returns 400' do
      resp = Sparko::Response::ApiResponse.bad_request('Invalid')
      _(resp.code).must_equal 400
      _(resp.status).must_equal :bad_request
    end

    it 'HAPPY: ApiResponse.not_found returns 404' do
      resp = Sparko::Response::ApiResponse.not_found('Missing')
      _(resp.code).must_equal 404
      _(resp.status).must_equal :not_found
    end

    it 'HAPPY: ApiResponse.error returns 500' do
      resp = Sparko::Response::ApiResponse.error('Crashed')
      _(resp.code).must_equal 500
      _(resp.status).must_equal :internal_error
    end
  end
end
