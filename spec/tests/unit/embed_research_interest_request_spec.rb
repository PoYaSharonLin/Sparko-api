# frozen_string_literal: true

require_relative '../../helpers/spec_helper'

describe Sparko::Request::EmbedResearchInterest do
  it 'HAPPY: accepts a normal term' do
    req = Sparko::Request::EmbedResearchInterest.new('term' => 'machine learning')
    _(req.valid?).must_equal true
  end

  it 'SAD: rejects empty string' do
    req = Sparko::Request::EmbedResearchInterest.new('term' => '   ')
    _(req.valid?).must_equal false
    _(req.error_code).must_equal :empty
  end

  it 'SAD: rejects non-string term' do
    req = Sparko::Request::EmbedResearchInterest.new('term' => 123)
    _(req.valid?).must_equal false
    _(req.error_code).must_equal :empty
  end

  it 'SAD: rejects too-long term' do
    req = Sparko::Request::EmbedResearchInterest.new('term' => 'a' * 501)
    _(req.valid?).must_equal false
    _(req.error_code).must_equal :too_long
  end

  it 'SAD: rejects control characters' do
    req = Sparko::Request::EmbedResearchInterest.new('term' => "hello\nworld")
    _(req.valid?).must_equal false
    _(req.error_code).must_equal :invalid_chars
  end
end