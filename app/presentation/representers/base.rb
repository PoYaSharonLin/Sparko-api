# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'
module Sparko
  module Representer
    # base class for other representers
    class Base < Roar::Decorator
      include Roar::JSON
    end
  end
end
