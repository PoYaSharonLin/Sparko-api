# frozen_string_literal: true

module AcaRadar
  # Library for Excerpt object
  class Excerpt
    def initialize(excerpt_data)
      # hot fix: only return the first hash
      @excerpt = excerpt_data.is_a?(Array) ? excerpt_data.first : excerpt_data
    end

    def id
      @id ||= @excerpt['id']
    end

    def title
      @title ||= @excerpt['title']
    end

    def summary
      @summary ||= @excerpt['summary']
    end
  end
end
