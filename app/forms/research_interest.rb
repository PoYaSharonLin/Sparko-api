# frozen_string_literal: true

require 'dry-validation'

module AcaRadar
  module Form
    # Form validation for single term
    class ResearchInterest < Dry::Validation::Contract
      RESEARCH_INTEREEST_REGEX = /\A[^,]+\z/
      MSG_INVALID_URL = 'cannot contain commas, please enter a single term'

      params do
        required(:single_term).filled(:string)
      end

      rule(:single_term) do
        key.failure(MSG_INVALID_URL) unless RESEARCH_INTEREEST_REGEX.match?(value)
      end
    end
  end
end
