require 'minitest/autorun'
require 'minitest/rg'
require 'yaml'

require_relative '../helper/arxiv_api_parser'
require_relative '../lib/arxiv_api'

CONFIG = YAML.safe_load_file('../config/secrets.yml', aliases: true)
CORRECT = YAML.safe_load_file('fixtures/arxiv_results.yml', aliases: true)

describe 'Test arXiv API library' do
  describe 'Excerpts Information' do 
    it 'HAPPY: should provide correct paper attributes' do 
      excerpts = AcaRadar::ArXivApi.new.excerpts()
      _(excerpts.title).must_equal CORRECT['entries'][0]['title']
      _(excerpts.summary).must_equal CORRECT['entries'][0]['summary']
    end 
  end

  describe 'Categories Information' do 
    it 'HAPPY: should provide correct categories attributes' do 
      categories = AcaRadar::ArXivApi.new.categories()
      _(categories.primary_category).must_equal CORRECT['entries'][0]['primary_category']
      _(categories.all_categories).must_equal CORRECT['entries'][0]['categories']
    end
  end

  describe 'Publications Information' do 
    it 'HAPPY: should provide correct publication attributes' do 
      publications = AcaRadar::ArXivApi.new.publications()
      _(publications.links).must_equal CORRECT['entries'][0]['links']
      _(publications.published).must_equal CORRECT['entries'][0]['published']
      _(publications.updated).must_equal CORRECT['entries'][0]['updated']
    end
  end

  describe 'Authors Information' do 
    it 'HAPPY: should provide correct author attributes' do 
      authors = AcaRadar::ArXivApi.new.authors()
      _(authors.id).must_equal CORRECT['entries'][0]['id']
      _(authors.authors).must_equal CORRECT['entries'][0]['authors']
    end
  end
end

