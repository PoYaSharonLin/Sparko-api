# frozen_string_literal: true

require_relative '../../helpers/spec_helper'

describe Sparko::Service::CalculateSimilarity do
  it 'HAPPY: returns 1.0 for identical vectors' do
    a = [1, 2, 3]
    b = [1, 2, 3]
    _(Sparko::Service::CalculateSimilarity.score(a, b)).must_be_within_delta 1.0, 1e-9
  end

  it 'HAPPY: returns 0.0 for orthogonal vectors' do
    a = [1, 0]
    b = [0, 1]
    _(Sparko::Service::CalculateSimilarity.score(a, b)).must_be_within_delta 0.0, 1e-9
  end

  it 'HAPPY: returns -1.0 for opposite vectors' do
    a = [1, 0]
    b = [-1, 0]
    _(Sparko::Service::CalculateSimilarity.score(a, b)).must_be_within_delta(-1.0, 1e-9)
  end

  it 'SAD: returns 0.0 when vectors are invalid (size mismatch)' do
    _(Sparko::Service::CalculateSimilarity.score([1, 2], [1])).must_equal 0.0
  end

  it 'SAD: returns 0.0 when denominator is zero (zero vector)' do
    _(Sparko::Service::CalculateSimilarity.score([0, 0], [1, 2])).must_equal 0.0
  end
end