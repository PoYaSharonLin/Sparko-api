# frozen_string_literal: true

require_relative '../helpers/spec_helper'
require_relative '../helpers/vcr_helper'
require_relative '../helpers/database_helper'
require 'rack/test'
require 'dry/monads'
require 'json'
require 'base64'
require 'ostruct'

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

  VALID_JOURNALS = [
  'MIS Quarterly',
  'Management Science',
  'Journal of the ACM'
].freeze

  def set_session(data = {})
    session_data = Marshal.dump(data)
    cookie = Base64.strict_encode64(session_data)
    header 'Cookie', "rack.session=#{cookie}"
  end

  describe 'Root route' do
    it 'should successfully return API welcome message' do
      get '/'
      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)
      _(body['status']).must_equal 'ok'
      _(body['message']).must_include 'AcaRadar API v1'
    end
  end

  describe 'POST /api/v1/research_interest' do
    it 'HAPPY: should successfully embed a valid research interest' do
      valid_term = 'information systems'
      vector_2d  = [0.75, -0.31]

      stub_service = Object.new
      stub_service.define_singleton_method(:call) do |term:|
        Dry::Monads::Success(vector_2d)
      end

      #  stub .new to return a lambda that returns stub_service
      AcaRadar::Service::EmbedResearchInterest.stub :new, ->(*) { stub_service } do
        post '/api/v1/research_interest',
         { term: valid_term }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }

        _(last_response.status).must_equal 201
        result = JSON.parse(last_response.body)

        _(result['term']).must_equal valid_term
        _(result['vector_2d']['x']).must_equal 0.75
        _(result['vector_2d']['y']).must_equal -0.31

        # session should be set
        session = last_request.env['rack.session']
        _(session[:research_interest_term]).must_equal valid_term
        _(session[:research_interest_2d]).must_equal vector_2d
      end
    end

    it 'SAD: should reject empty term' do
      post '/api/v1/research_interest',
       { term: '' }.to_json,
       { 'CONTENT_TYPE' => 'application/json' }
      
      _(last_response.status).must_equal 400
      result = JSON.parse(last_response.body)
      _(result['details']).must_include 'non-empty'
    end
  end

  describe 'GET /api/v1/papers' do
    let(:sample_papers) do
      3.times.map { |i| OpenStruct.new(id: i + 1, title: "IS Paper #{i + 1}") }
    end

    before do
      # Set a valid session for most tests
      set_session(
        research_interest_term: 'information systems',
        research_interest_2d: [0.75, -0.31]
      )
    end

    # it 'HAPPY: should work with any combination of the three allowed journals' do
    #   VALID_JOURNALS.permutation(2).each do |j1, j2|
    #     AcaRadar::Repository::Paper.stub :find_by_categories, sample_papers do
    #       AcaRadar::Repository::Paper.stub :count_by_categories, 15 do
    #         get "/api/v1/papers?journal1=#{URI.encode_www_form_component(j1)}&journal2=#{URI.encode_www_form_component(j2)}"

    #         _(last_response.status).must_equal 200, "Failed for #{j1} vs #{j2}"
    #         json = JSON.parse(last_response.body)['data']['attributes']
    #         _(json['journals']).must_include j1
    #         _(json['journals']).must_include j2
    #       end
    #     end
    #   end
    # end

    # it 'SAD: should reject when same journal is selected twice' do
    #   get '/api/v1/papers?journal1=Journal of the ACM&journal2=Journal of the ACM'

    #   _(last_response.status).must_equal 200
    #   _(JSON.parse(last_response.body)['error']['message'])
    #     .must_include 'two different journals'
    # end

    # it 'SAD: should reject invalid or unknown journals' do
    #   get '/api/v1/papers?journal1=Nature&journal2=Science'

    #   _(last_response.status).must_equal 200
    #   message = JSON.parse(last_response.body)['error']['message']
    #   _(message).must_match(/invalid|unknown|allowed/i)
    # end
  end
end