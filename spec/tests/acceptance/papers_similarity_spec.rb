# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'
require 'dry/monads'
require 'json'
require 'base64'
require 'digest'

def app
  AcaRadar::App
end

describe 'GET /api/v1/papers (similarity mode)' do
  include Rack::Test::Methods
  include Dry::Monads[:result]

  before do
    DatabaseHelper.wipe_database
    # DatabaseHelper doesn't wipe research_interest_jobs; do it here to avoid cross-test pollution
    if defined?(AcaRadar::Database::ResearchInterestJobOrm)
      AcaRadar::Database::ResearchInterestJobOrm.dataset.delete
    elsif app.respond_to?(:db)
      app.db[:research_interest_jobs].delete rescue nil
    end
  end

  def parsed_response
    JSON.parse(last_response.body)
  end

  def extract_papers_array(body_hash)
    papers = body_hash.dig('data', 'papers')
    return papers if papers.is_a?(Array)
    return papers['data'] if papers.is_a?(Hash) && papers['data'].is_a?(Array)
    []
  end

  def safe_create_paper(attrs)
    cols = AcaRadar::Database::PaperOrm.columns
    filtered = attrs.select { |k, _| cols.include?(k) }
    AcaRadar::Database::PaperOrm.create(filtered)
  end

  def safe_create_job(attrs)
    cols = AcaRadar::Database::ResearchInterestJobOrm.columns
    filtered = attrs.select { |k, _| cols.include?(k) }
    AcaRadar::Database::ResearchInterestJobOrm.create(filtered)
  end

  def pack_embedding_to_b64(vec)
    Base64.strict_encode64(Array(vec).map(&:to_f).pack('e*')) # float32 little-endian
  end

  def seed_paper(origin_id:, title:, embedding:, journal: 'MIS Quarterly', published: Time.utc(2022, 1, 1))
    safe_create_paper(
      origin_id: origin_id,
      title: title,
      published: published,
      summary: "Summary #{title}",
      short_summary: "Short #{title}",
      journal: journal,
      # IMPORTANT: store links as JSON ARRAY so Entity::Paper#pdf_url doesn't blow up
      links: JSON.generate([
        { 'type' => 'application/pdf', 'href' => "https://example.org/#{origin_id}.pdf" },
        { 'type' => 'text/html', 'href' => "https://example.org/abs/#{origin_id}" }
      ]),
      authors: JSON.generate([{ 'name' => 'Alice' }]),
      concepts: JSON.generate([]),
      categories: JSON.generate([]),
      two_dim_embedding: JSON.generate([0.0, 0.0]),
      embedding: JSON.generate(Array(embedding))
    )
  end

  def seed_job(job_id:, term:, status:, embedding: nil, vector_2d: [0.12, -0.34], concepts: %w[a b])
    attrs = {
      job_id: job_id,
      term: term,
      status: status,
      vector_x: vector_2d[0],
      vector_y: vector_2d[1],
      created_at: Time.now.utc,
      updated_at: Time.now.utc,
      concepts_json: Array(concepts).to_json
    }

    if embedding
      attrs[:embedding_b64] = pack_embedding_to_b64(embedding)
      attrs[:embedding_dim] = Array(embedding).length
    end

    safe_create_job(attrs)
  end

  it 'HAPPY: request_id present but job not completed returns 202 processing (when request params are valid)' do
    seed_job(job_id: 'jid_processing', term: 'machine learning', status: 'processing')

    get '/api/v1/papers',
        { journals: ['MIS Quarterly'], page: '1', request_id: 'jid_processing' },
        { 'CONTENT_TYPE' => 'application/json' }

    _(last_response.status).must_equal 202
    body = parsed_response
    _(body['status']).must_equal 'processing'
    _(body['message']).must_include 'processing'
    _(body.dig('data', 'request_id')).must_equal 'jid_processing'
    _(body.dig('data', 'status_url')).must_include '/api/v1/research_interest/'
  end

  it 'HAPPY: completed request_id + top_n returns highest-similarity papers first' do
    # research embedding = [1, 0]
    seed_job(job_id: 'jid_completed', term: 'machine learning', status: 'completed', embedding: [1.0, 0.0])

    # Papers: A=1.0, B=0.0, C=-1.0 cosine similarity vs [1,0]
    seed_paper(origin_id: 'A', title: 'A', embedding: [1.0, 0.0], published: Time.utc(2024, 1, 1))
    seed_paper(origin_id: 'B', title: 'B', embedding: [0.0, 1.0], published: Time.utc(2023, 1, 1))
    seed_paper(origin_id: 'C', title: 'C', embedding: [-1.0, 0.0], published: Time.utc(2022, 1, 1))

    get '/api/v1/papers',
        { journals: ['MIS Quarterly'], page: '1', request_id: 'jid_completed', top_n: '2' },
        { 'CONTENT_TYPE' => 'application/json' }

    _(last_response.status).must_equal 200
    body = parsed_response
    _(body['status']).must_equal 'ok'
    _(body.dig('data', 'research_interest_term')).must_equal 'machine learning'

    papers = extract_papers_array(body)
    _(papers.length).must_equal 2
    _(papers.map { |p| p['title'] }).must_equal %w[A B]
  end

  it 'HAPPY: journal filter excludes papers from other journals' do
    seed_job(job_id: 'jid_completed2', term: 'ml', status: 'completed', embedding: [1.0, 0.0])

    seed_paper(origin_id: 'A', title: 'A', embedding: [1.0, 0.0], journal: 'MIS Quarterly')
    seed_paper(origin_id: 'X', title: 'X', embedding: [1.0, 0.0], journal: 'Information Systems Research')

    get '/api/v1/papers',
        { journals: ['MIS Quarterly'], page: '1', request_id: 'jid_completed2', top_n: '10' },
        { 'CONTENT_TYPE' => 'application/json' }

    _(last_response.status).must_equal 200
    titles = extract_papers_array(parsed_response).map { |p| p['title'] }
    _(titles).must_include 'A'
    _(titles).wont_include 'X'
  end

  it 'HAPPY: min_date filter excludes older papers' do
    seed_job(job_id: 'jid_completed3', term: 'ml', status: 'completed', embedding: [1.0, 0.0])

    seed_paper(origin_id: 'NEW', title: 'NEW', embedding: [1.0, 0.0], published: Time.utc(2024, 1, 1))
    seed_paper(origin_id: 'OLD', title: 'OLD', embedding: [1.0, 0.0], published: Time.utc(2010, 1, 1))

    get '/api/v1/papers',
        { journals: ['MIS Quarterly'], page: '1', request_id: 'jid_completed3', top_n: '10', min_date: '2020-01-01' },
        { 'CONTENT_TYPE' => 'application/json' }

    _(last_response.status).must_equal 200
    titles = extract_papers_array(parsed_response).map { |p| p['title'] }
    _(titles).must_include 'NEW'
    _(titles).wont_include 'OLD'
  end

  it 'HAPPY: ETag is stable and returns 304 when If-None-Match matches' do
    seed_job(job_id: 'jid_completed4', term: 'ml', status: 'completed', embedding: [1.0, 0.0])
    seed_paper(origin_id: 'A', title: 'A', embedding: [1.0, 0.0])

    get '/api/v1/papers',
        { journals: ['MIS Quarterly'], page: '1', request_id: 'jid_completed4', top_n: '1' },
        { 'CONTENT_TYPE' => 'application/json' }

    _(last_response.status).must_equal 200
    etag = last_response.headers['ETag']
    _(etag).wont_be_nil

    header 'If-None-Match', etag
    get '/api/v1/papers',
        { journals: ['MIS Quarterly'], page: '1', request_id: 'jid_completed4', top_n: '1' },
        { 'CONTENT_TYPE' => 'application/json' }

    _(last_response.status).must_equal 304
  end
end