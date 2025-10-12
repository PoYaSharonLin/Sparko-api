# frozen_string_literal: true

module AcaRadar
  # Library for Author object
  class Author
    def initialize(author_data)
      @author = author_data.is_a?(Array) ? author_data.first : author_data
    end

    def id
      @id ||= @author['id']
    end

    def authors
      @authors ||= @author['authors']
    end
  end
end
