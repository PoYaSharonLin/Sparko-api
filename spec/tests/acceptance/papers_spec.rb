# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/vcr_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'
require 'dry/monads'
require 'json'
require 'base64'
require 'time'
require 'ostruct'

# rubocop:disable Lint/UnusedBlockArgument
def app
  Sparko::App
end

describe 'GET /api/v1/papers' do
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
    body = last_response.body.to_s
    return {} if body.strip.empty?
    JSON.parse(body)
  end  

  def stub_list_request(valid: true, journals: ['MIS Quarterly'], page: 1, min_date: nil, max_date: nil, error_message: 'Invalid')
    req = Object.new
    req.define_singleton_method(:valid?) { valid }
    req.define_singleton_method(:journals) { journals }
    req.define_singleton_method(:page) { page }
    req.define_singleton_method(:min_date) { min_date }
    req.define_singleton_method(:max_date) { max_date }
    req.define_singleton_method(:error_message) { error_message }
  req
  end

  it 'SAD: invalid request returns 400' do
  req = stub_list_request(valid: false, error_message: 'Bad params')

  Sparko::Request::ListPapers.stub :new, ->(*) { req } do
    get '/api/v1/papers'
    _(last_response.status).must_equal 400

    body = parsed_response
      _(body['status']).must_equal 'bad_request'
      _(body['message']).must_equal 'Bad params'
    end
  end

  it 'SAD: top_n requires a completed embedded research interest' do
  req = stub_list_request(valid: true)

  Sparko::Request::ListPapers.stub :new, ->(*) { req } do
    get '/api/v1/papers?top_n=5'
    _(last_response.status).must_equal 400

    body = parsed_response
      _(body['status']).must_equal 'bad_request'
      _(body['message']).must_include 'top_n requires an embedded research interest'
    end
  end

  it 'HAPPY: request_id present but job not completed returns 202 + status_url' do
  req = stub_list_request(valid: true)
  job = OpenStruct.new(job_id: 'jid', status: 'processing')

  Sparko::Request::ListPapers.stub :new, ->(*) { req } do
    Sparko::Repository::ResearchInterestJob.stub :find, job do
      get '/api/v1/papers?request_id=jid'
      _(last_response.status).must_equal 202

      body = parsed_response
        _(body['status']).must_equal 'processing'
        _(body.dig('data', 'request_id')).must_equal 'jid'
        _(body.dig('data', 'status_url')).must_equal '/api/v1/research_interest/jid'
      end
    end
  end

  it 'HAPPY: completed job returns papers (200) and includes RI fields' do
  req = stub_list_request(valid: true, journals: ['MIS Quarterly'], page: 1)

  emb = [1.0, 0.0, 0.0]
  b64 = Base64.strict_encode64(emb.pack('e*'))

  job = OpenStruct.new(
    job_id: 'jid',
    status: 'completed',
    term: 'machine learning',
    vector_x: 0.9,
    vector_y: -0.1,
    embedding_b64: b64
  )

  PaperStub = Struct.new(
    :paper_id, :origin_id, :title, :summary, :short_summary,
    :published, :updated, :journal,
    :authors, :categories, :concepts, :links,
    :embedding, :two_dim_embedding,
    :similarity_score,
    keyword_init: true
  ) do
    # some representers call published, some call published_at
    def published_at = published
  end

  paper1 = OpenStruct.new(
    paper_id: 1,
    origin_id: 'o1',
    title: 'Paper A',
    summary: 'Summary A',
    short_summary: 'Short A',
    journal: 'MIS Quarterly',
    published: Time.parse('2024-01-01T00:00:00Z'),
    published_at: Time.parse('2024-01-01T00:00:00Z'),
    updated: Time.parse('2024-01-02T00:00:00Z'),
    updated_at: Time.parse('2024-01-02T00:00:00Z'),
    pdf_url: 'https://example.com/a.pdf',
    html_url: 'https://example.com/a',
    doi_url: nil,
    arxiv_url: nil,
    authors: [],
    categories: [],
    concepts: [],
    links: [],
    similarity_score: 0.99,
    embedding: [0.1, 0.2],
    two_dim_embedding: [0.0, 0.0]
    )

    paper2 = OpenStruct.new(
      paper_id: 2,
      origin_id: 'o2',
      title: 'Paper B',
      summary: 'Summary B',
      short_summary: 'Short B',
      journal: 'MIS Quarterly',
      published: Time.parse('2024-02-01T00:00:00Z'),
      published_at: Time.parse('2024-02-01T00:00:00Z'),
      updated: Time.parse('2024-02-02T00:00:00Z'),
      updated_at: Time.parse('2024-02-02T00:00:00Z'),
      pdf_url: 'https://example.com/b.pdf',
      html_url: 'https://example.com/b',
      doi_url: nil,
      arxiv_url: nil,
      authors: [],
      categories: [],
      concepts: [],
      links: [],
      similarity_score: 0.12,
      embedding: [0.2, 0.1],
      two_dim_embedding: [0.0, 0.0]
    )



  list_service = Object.new
  list_service.extend(Dry::Monads[:result])
  list_service.define_singleton_method(:call) do |journals:, page:, research_embedding:, top_n:, min_date:, max_date:|
    list = OpenStruct.new(
    papers: [paper1, paper2],
    pagination: { mode: 'paged', current: 1, total_pages: 1, total_count: 2, prev_page: nil, next_page: nil }
    )
    Success(list)
  end

  Sparko::Request::ListPapers.stub :new, ->(*) { req } do
    Sparko::Repository::ResearchInterestJob.stub :find, job do
        Sparko::Service::ListPapers.stub :new, ->(*) { list_service } do
        get '/api/v1/papers?request_id=jid'
        _(last_response.status).must_equal 200

        body = parsed_response
          _(body['status']).must_equal 'ok'
          _(body['data']).wont_be_nil

          _(body.dig('data', 'research_interest_term')).must_equal 'machine learning'
          _(body.dig('data', 'research_interest_2d')).must_equal [0.9, -0.1]
          _(body.dig('data', 'journals')).must_equal ['MIS Quarterly']
        end
      end
    end
  end

  it 'HAPPY: supports ETag caching on papers list (304 when unchanged)' do
  req = stub_list_request(valid: true, journals: ['MIS Quarterly'], page: 1)

  job = OpenStruct.new(job_id: 'jid', status: 'completed', term: 't', vector_x: 0.0, vector_y: 0.0, embedding_b64: '')

  list_service = Object.new
  list_service.extend(Dry::Monads[:result])
  list_service.define_singleton_method(:call) do |**_kwargs|
    list = OpenStruct.new(papers: [], pagination: { mode: 'paged', current: 1, total_pages: 0, total_count: 0, prev_page: nil, next_page: nil })
    Success(list)
  end

  Sparko::Request::ListPapers.stub :new, ->(*) { req } do
    Sparko::Repository::ResearchInterestJob.stub :find, job do
      Sparko::Service::ListPapers.stub :new, ->(*) { list_service } do
        get '/api/v1/papers?request_id=jid'
        _(last_response.status).must_equal 200

        etag = last_response.headers['ETag']
        _(etag).wont_be_nil

        header 'If-None-Match', etag
        get '/api/v1/papers?request_id=jid'
        _(last_response.status).must_equal 304

        body = parsed_response
          _(body['status']).must_equal 'not_modified'
          _(body['message']).must_equal 'Not Modified'
        end
      end
    end
  end
end
# rubocop:enable Lint/UnusedBlockArgument
