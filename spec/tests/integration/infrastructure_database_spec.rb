# frozen_string_literal: true

# # frozen_string_literal: false

# require_relative '../../helpers/spec_helper'
# require_relative '../../helpers/vcr_helper'
# require_relative '../../helpers/database_helper'
# require 'pry'

# describe 'Integration Tests of arxiv API and Database' do
#   VcrHelper.setup_vcr

#   before do
#     VcrHelper.configure_vcr
#   end

#   after do
#     VcrHelper.eject_vcr
#   end

#   describe 'Retrieve and store project' do
#     before do
#       DatabaseHelper.wipe_database
#     end

#     it 'HAPPY: should be able to save author from arxiv to database' do
#       journals = ['MIS Quarterly', 'Nature']
#       query = AcaRadar::Query.new(journals: journals)
#       api = AcaRadar::ArXivApi.new
#       api_response = api.call(query)
#       papers = api_response.papers
#       papers.each do |paper|
#         authors = paper.authors
#         authors.map do |author|
#           AcaRadar::Repository::Lookup.entity(author).create(author)
#         end
#         first_author = authors.first
#         found = AcaRadar::Repository::Author.find_name(first_author.name)
#         _(found.name).must_include(first_author.name)
#       end
#     end
#   end
# end
