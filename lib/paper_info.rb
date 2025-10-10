# frozen_string_literal: true

require 'http'
require 'net/http'
require 'uri'
require 'pry'
require 'nokogiri'
require 'yaml'

def arxiv_api_path(path)
  "http://export.arxiv.org/api/#{path}"
end 


url = URI.parse(arxiv_api_path('query?search_query=all:information&start=0&max_results=5'))
init_res = Net::HTTP.get_response(url)


redirect_url = URI.parse(init_res['location'])
res = Net::HTTP.get_response(redirect_url) #data structure: xml 
xml = res.body

# Parse XML with Nokogiri
doc = Nokogiri::XML(xml)

# Initialize the result array
result = []

# Process each <feed> element
doc.search('feed').each do |feed|
  feed_hash = {}

  # Extract <title> with its type attribute
  title_node = feed.at('title')
  feed_hash[:TitleType] = "#{title_node['type']}\">#{title_node.text}"

  # Extract <id> and <updated>
  feed_hash[:id] = feed.at('id').text
  feed_hash[:updated] = feed.at('updated').text

  # Process <entry> elements
  entries = feed.search('entry').map do |entry|
    entry_hash = {
      id: entry.at('id')&.text&.strip || "",
      updated: entry.at('updated')&.text&.strip || "",
      published: entry.at('published')&.text&.strip || "",
      title: entry.at('title')&.text&.strip || "",
      summary: entry.at('summary')&.text&.strip || "",
      author: entry.at('author')&.text&.strip || "",
    }
    entry_hash
  end

  # Add entries to feed hash
  feed_hash[:entry] = entries

  # Add the feed hash to the result array
  result << feed_hash
end

File.write('spec/fixtures/arxiv_results.yml', result.to_yaml)









