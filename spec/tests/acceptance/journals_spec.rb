# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require 'rack/test'
require 'json'

def app
  Sparko::App
end

describe 'GET /api/v1/journals' do
  include Rack::Test::Methods

  def parsed_response
    JSON.parse(last_response.body)
  end

  it 'HAPPY: returns domains list with labels and journals' do
    get '/api/v1/journals'

    _(last_response.status).must_equal 200
    body = parsed_response

    _(body['status']).must_equal 'ok'
    _(body['data']).wont_be_nil
    _(body['data']['domains']).must_be_kind_of Array
    _(body['data']['domains'].first).must_be_kind_of Hash
    _(body['data']['domains'].first).must_include 'label'
    _(body['data']['domains'].first).must_include 'journals'
  end
end