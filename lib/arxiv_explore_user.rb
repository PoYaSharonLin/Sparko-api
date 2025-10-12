# frozen_string_literal: true

require 'http'
require 'uri'
require 'nokogiri'
require 'tactful_tokenizer'
require 'engtagger'

# Simple code to explore the ArXiV API, and a simple keyword extractor ruby package.

def keyword_extraction(text)
  tokenizer = TactfulTokenizer::Model.new
  sentences = tokenizer.tokenize_text(text)

  tgr = EngTagger.new
  tagged = tgr.add_tags(sentences.join(' '))
  tgr.get_nouns(tagged).keys.join('+')
end

def xml_parse_and_output(xml)
  doc = Nokogiri::XML(xml)
  doc.xpath('//xmlns:entry').each do |entry|
    puts "Title: #{entry.xpath('xmlns:title').text.strip}"
    puts "Authors: #{entry.xpath('xmlns:author/xmlns:name').map(&:text).join(', ')}"
    puts "Summary: #{entry.xpath('xmlns:summary').text.strip}"
    puts
  end
end

def run
  puts 'Hello! Please describe what kind of article you are looking for.'
  puts 'We will pull two articles from ArXiV matching the keywords of your prompt.'
  url = URI("https://export.arxiv.org/api/query?search_query=#{keyword_extraction(gets.strip)}&start=0&max_results=2")
  req = HTTP::Get.new(url)
  req['User-Agent'] = 'Sangria/1.0'
  res = HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(req) }
  XML_parse_and_output(res.body)
end

run
