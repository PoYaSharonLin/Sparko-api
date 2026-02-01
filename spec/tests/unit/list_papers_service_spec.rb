# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require 'dry/monads'
require 'ostruct'

describe Sparko::Service::ListPapers do
  include Dry::Monads[:result]

  PaperDouble = Struct.new(:title, :embedding, :similarity_score, keyword_init: true)

  let(:service) { Sparko::Service::ListPapers.new }

  it 'HAPPY: computes similarity and returns top_n results sorted' do
    # Research vector = [1,0]
    ri = [1.0, 0.0]

    a = PaperDouble.new(title: 'A', embedding: [1.0, 0.0])  # score 1
    b = PaperDouble.new(title: 'B', embedding: [0.0, 1.0])  # score 0
    c = PaperDouble.new(title: 'C', embedding: [-1.0, 0.0]) # score -1

    Sparko::Repository::Paper.stub(:find_by_categories, [b, c, a]) do
      res = service.call(journals: [], page: 1, research_embedding: ri, top_n: '2')
      _(res).must_be :success?

      list = res.value!
      _(list.pagination[:mode]).must_equal 'top_n'
      _(list.papers.map(&:title)).must_equal ['A', 'B']
      _(list.papers.first.similarity_score).must_be_within_delta 1.0, 1e-9
    end
  end

  it 'HAPPY: paged mode when top_n is missing' do
    papers = (1..30).map { |i| PaperDouble.new(title: "P#{i}", embedding: [1.0, 0.0]) }

    Sparko::Repository::Paper.stub(:find_by_categories, papers) do
      res = service.call(journals: [], page: 2, research_embedding: nil, top_n: nil)
      _(res).must_be :success?
      list = res.value!

      _(list.pagination[:mode]).must_equal 'paged'
      _(list.pagination[:current]).must_equal 2
      _(list.papers.length).must_equal 5
      _(list.papers.first.title).must_equal 'P26'
    end
  end

  it 'SAD: invalid top_n falls back to paged mode' do
    papers = (1..5).map { |i| PaperDouble.new(title: "P#{i}", embedding: [1.0, 0.0]) }

    Sparko::Repository::Paper.stub(:find_by_categories, papers) do
      res = service.call(journals: [], page: 1, research_embedding: [1.0, 0.0], top_n: '0')
      _(res).must_be :success?
      list = res.value!
      _(list.pagination[:mode]).must_equal 'paged'
    end
  end

  it 'SAD: skips papers with empty embeddings (similarity_score stays nil)' do
    good = PaperDouble.new(title: 'GOOD', embedding: [1.0, 0.0])
    bad  = PaperDouble.new(title: 'BAD',  embedding: [])

    Sparko::Repository::Paper.stub(:find_by_categories, [bad, good]) do
      res = service.call(journals: [], page: 1, research_embedding: [1.0, 0.0], top_n: '2')
      _(res).must_be :success?
      list = res.value!
      titles = list.papers.map(&:title)
      _(titles).must_equal ['GOOD', 'BAD']
      _(list.papers.last.similarity_score).must_be_nil
    end
  end
end