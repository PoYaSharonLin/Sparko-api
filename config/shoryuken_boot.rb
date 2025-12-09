# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'development'

require_relative 'environment'
require_relative '../require_app'
require_relative '../app/workers/embed_research_interest_worker'
