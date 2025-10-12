# frozen_string_literal: true

require 'http'
require 'yaml'
require 'uri'

# stdlib
require 'rexml/document'
require 'rexml/xpath'
require 'cgi'
require 'time'

# helper
require_relative '../helper/arxiv_api_parser'

# -------------------------------------------------------------------
# Config
# -------------------------------------------------------------------
config = YAML.safe_load_file('../config/secrets.yml')

# -------------------------------------------------------------------
# Requests
# -------------------------------------------------------------------
arxiv_response = {}
arxiv_results  = {}

## HAPPY arXiv request
query_base = 'all:Reinforcement Learning'

# Use full-day window; arXiv expects YYYYMMDDHHMM UTC
min_date_arxiv = '201010020000'
max_date_arxiv = '202510020000'

query = "#{query_base} AND submittedDate:[#{min_date_arxiv} TO #{max_date_arxiv}]"

max_results = 50
sort_by     = 'submittedDate'
sort_order  = 'ascending'

params = URI.encode_www_form(
  'search_query' => query,
  'start' => 0,
  'max_results' => max_results,
  'sortBy' => sort_by,
  'sortOrder' => sort_order
)

parser = AcaRadar::ArXivApiParser.new
good_url = parser.arxiv_api_path("query?#{params}")
puts "GOOD URL: #{good_url}"

resp = parser.call_arxiv_url(config, good_url)
puts "HTTP STATUS: #{resp.status}"

good_atom = resp.to_s
good_parsed = parser.parse_arxiv_atom(good_atom)

arxiv_results['meta'] = {
  'query' => query,
  'max_results' => max_results,
  'sort_by' => sort_by,
  'sort_order' => sort_order,
  'fetched_at' => Time.now.utc.iso8601
}

arxiv_results['total_results'] = good_parsed['total_results']
# usually a large integer

arxiv_results['entries'] = good_parsed['entries']
# should be an array of entries (size <= max_results)

arxiv_results['titles'] = (good_parsed['entries'] || []).map { |e| e['title'] }
# should be an array of paper titles

arxiv_results['first_entry_authors'] = (good_parsed['entries']&.first || {})['authors']
# should be an array of author names for the first entry (if any)

## BAD arXiv request (intentionally wrong path to simulate a failure)
bad_url = parser.arxiv_api_path('querty?search_query=all:foo') # typo: "querty"
arxiv_response[bad_url] = parser.call_arxiv_url(config, bad_url)
arxiv_response[bad_url].to_s # ensure body is fully read

# -------------------------------------------------------------------
# Output
# -------------------------------------------------------------------
File.write('../spec/fixtures/arxiv_results.yml', arxiv_results.to_yaml)
