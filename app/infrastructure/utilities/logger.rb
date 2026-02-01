# frozen_string_literal: true

require 'logger'

module Sparko
  LOGGER = Logger.new($stdout)
  LOGGER.level = Logger.const_get((ENV['LOG_LEVEL'] || 'DEBUG').upcase) rescue Logger::DEBUG

  def self.logger
    LOGGER
  end
end
