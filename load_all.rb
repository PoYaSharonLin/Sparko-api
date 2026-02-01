# frozen_string_literal: true

require_relative 'require_app'
require_app

def app = Sparko::App

# Load models
Dir[File.expand_path('app/models/*_orm.rb', __dir__)].each do |file|
  require file
end
