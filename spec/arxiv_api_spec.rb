# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/rg'
require 'yaml'
require 'ostruct'
require 'cgi'

require_relative '../helper/arxiv_api_parser'
require_relative '../lib/arxiv_api'
require_relative 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe 'Test arXiv API library' do
  VCR.configure do |c|
    c.cassette_library_dir = CASSETTES_FOLDER
    c.hook_into :webmock
  end

  before do
    VCR.insert_cassette CASSETTE_FILE,
                        record: :new_episodes,
                        match_requests_on: %i[method uri headers]
  end

  after do
    VCR.eject_cassette
  end

  describe 'Query class' do
    it 'HAPPY: should build correct query url' do
      query = AcaRadar::Query.new(base_query: 'all:Reinforcement Learning', max_results: 5)
      url = query.url

      encoded = url.match(/search_query=([^&]+)/)[1]
      decoded = CGI.unescape(encoded)

      _(decoded).must_include 'all:Reinforcement Learning'
      _(url).must_include 'max_results=5'
    end
  end

  describe 'Categories class' do
    it 'HAPPY: should return correct categories and primary' do
      entry = CORRECT['entries'][0]
      categories = AcaRadar::Categories.new(entry['categories'], entry['primary_category'])

      _(categories.all).must_equal Array(entry['categories'])
      _(categories.primary).must_equal entry['primary_category']
      _(categories.to_h).must_equal({
                                      primary_category: entry['primary_category'],
                                      categories: Array(entry['categories'])
                                    })
    end

    it 'HAPPY: handles nils and duplicates correctly' do
      input = [nil, 'cs.AI', 'cs.AI', 'stat.ML']
      categories = AcaRadar::Categories.new(input, nil)

      _(categories.all).must_equal ['cs.AI', 'stat.ML']
      _(categories.primary).must_be_nil
      _(categories.to_h).must_equal({ categories: ['cs.AI', 'stat.ML'] })
    end
  end

  describe 'Author class' do
    it 'HAPPY: parses and formats multi-part names' do
      author = AcaRadar::Author.new('John Q. Public')

      _(author.name).must_equal 'John Q. Public'
      _(author.first_name).must_equal 'John Q.'
      _(author.last_name).must_equal 'Public'

      _(author.full).must_equal 'John Q. Public'
      _(author.short).must_equal 'J. Public'
      _(author.citation).must_equal 'Public, John Q.'
      _(author.initials).must_equal 'J.Q.P.'

      _(author.format(:short)).must_equal 'J. Public'
      _(author.to_s).must_equal 'John Q. Public'
      _(author.to_h).must_equal({ name: 'John Q. Public', first_name: 'John Q.', last_name: 'Public' })
    end

    it 'SAD: handles single-name authors' do
      author = AcaRadar::Author.new('Madonna')

      _(author.name).must_equal 'Madonna'
      _(author.first_name).must_equal 'Madonna'
      _(author.last_name).must_be_nil

      _(author.full).must_equal 'Madonna'
      _(author.short).must_equal 'Madonna'
      _(author.citation).must_equal 'Madonna'
      _(author.initials).must_equal 'M.'
      _(author.format(:initials)).must_equal 'M.'
    end
  end

  describe 'Paper class' do
    it 'HAPPY: should initialize with correct attributes' do
      entry = CORRECT['entries'][0]
      paper = AcaRadar::Paper.new(entry)

      _(paper.id).must_equal entry['id']
      _(paper.title).must_equal entry['title']
      _(paper.published).must_equal entry['published']
      _(paper.updated).must_equal entry['updated']

      _(paper.authors.map(&:name)).must_equal Array(entry['authors'])

      _(paper.categories.all).must_equal Array(entry['categories'])
      _(paper.categories.primary).must_equal entry['primary_category']

      _(paper.links).must_equal Array(entry['links'])
    end
  end
end
# rubocop:enable Metrics/BlockLength
