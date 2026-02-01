# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require 'dry/monads'
require 'securerandom'

describe Sparko::Service::QueueResearchInterestEmbedding do
  include Dry::Monads[:result]

  it 'HAPPY: cache hit returns existing job_id and does not publish' do
    cached = OpenStruct.new(job_id: 'cached_1')
    published = false
    created = false

    Sparko::Repository::ResearchInterestJob.stub :find_completed_by_term, cached do
      Sparko::Repository::ResearchInterestJob.stub :create, ->(**_args) { created = true } do
        Sparko::Messaging::SqsClient.stub :publish, ->(**_args) { published = true } do
          result = Sparko::Service::QueueResearchInterestEmbedding.new.call(term: '  Machine   Learning ')
          _(result).must_be_kind_of Dry::Monads::Result::Success
          _(result.value!).must_equal 'cached_1'
          _(created).must_equal false
          _(published).must_equal false
        end
      end
    end
  end

  it 'HAPPY: cache miss creates job + publishes and returns new job_id' do
    created_args = nil
    published_args = nil

    Sparko::Repository::ResearchInterestJob.stub :find_completed_by_term, nil do
      SecureRandom.stub :uuid, 'uuid-123' do
        Sparko::Repository::ResearchInterestJob.stub :create, ->(**args) { created_args = args } do
          Sparko::Messaging::SqsClient.stub :publish, ->(**args) { published_args = args } do
            result = Sparko::Service::QueueResearchInterestEmbedding.new.call(term: "  Machine   Learning\n")
            _(result).must_be_kind_of Dry::Monads::Result::Success
            _(result.value!).must_equal 'uuid-123'

            _(created_args[:job_id]).must_equal 'uuid-123'
            _(created_args[:term]).must_equal 'machine learning'

            _(published_args[:type]).must_equal 'embed_research_interest'
            _(published_args[:job_id]).must_equal 'uuid-123'
            _(published_args[:term]).must_equal 'machine learning'
          end
        end
      end
    end
  end

  it 'SAD: exceptions return Failure' do
    Sparko::Repository::ResearchInterestJob.stub :find_completed_by_term, nil do
      SecureRandom.stub :uuid, 'uuid-err' do
        Sparko::Repository::ResearchInterestJob.stub :create, ->(**_args) { true } do
          Sparko::Messaging::SqsClient.stub :publish, ->(**_args) { raise 'boom' } do
            result = Sparko::Service::QueueResearchInterestEmbedding.new.call(term: 'x')
            _(result).must_be_kind_of Dry::Monads::Result::Failure
          end
        end
      end
    end
  end
end
