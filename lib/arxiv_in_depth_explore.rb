# frozen_string_literal: true

require 'http'
require 'yaml'
require 'uri'

# stdlib
require 'rexml/document'
require 'rexml/xpath'
require 'cgi'
require 'time'

# -------------------------------------------------------------------
# Config
# -------------------------------------------------------------------
# config/secrets.yml example:
# ARXIV_USER_AGENT: "Sangria/1.0 (mailto:you@example.com)"
config = YAML.safe_load_file('config/secrets.yml')

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
def arxiv_api_path(path)
  "https://export.arxiv.org/api/#{path}"
end

def call_arxiv_url(config, url)
  ua = config['ARXIV_USER_AGENT'].to_s
  HTTP.headers(
    'Accept' => 'application/atom+xml',
    'User-Agent' => ua
  ).get(url)
end

def parse_arxiv_atom(xml_str)
  doc = REXML::Document.new(xml_str)

  total_results = REXML::XPath.first(doc, '//opensearch:totalResults')&.text&.to_i
  start_index   = REXML::XPath.first(doc, '//opensearch:startIndex')&.text&.to_i
  items_per_pg  = REXML::XPath.first(doc, '//opensearch:itemsPerPage')&.text&.to_i

  entries = []
  REXML::XPath.each(doc, '//entry') do |e|
    title     = e.elements['title']&.text&.strip
    summary   = e.elements['summary']&.text&.strip
    published = e.elements['published']&.text&.strip
    updated   = e.elements['updated']&.text&.strip
    id        = e.elements['id']&.text&.strip

    authors = e.get_elements('author/name').map { |n| n.text.to_s.strip }.uniq
    cats    = e.get_elements('category').map { |c| c.attributes['term'] }.compact.uniq
    pcat    = e.elements['arxiv:primary_category']&.attributes&.[]('term')

    links = e.get_elements('link').map do |l|
      {
        'rel'   => l.attributes['rel'],
        'type'  => l.attributes['type'],
        'href'  => l.attributes['href'],
        'title' => l.attributes['title']
      }.compact
    end

    entries << {
      'id'  => id,
      'title' => title,
      'summary' => summary,
      'published' => published,
      'updated' => updated,
      'authors' => authors,
      'categories' => cats,
      'primary_category' => pcat,
      'links' => links
    }.compact
  end

  {
    'total_results' => total_results,
    'start_index' => start_index,
    'items_per_page' => items_per_pg,
    'entries' => entries
  }.compact
end

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
  'start'        => 0,
  'max_results'  => max_results,
  'sortBy'       => sort_by,
  'sortOrder'    => sort_order
)

good_url = arxiv_api_path("query?#{params}")
puts "GOOD URL: #{good_url}"

resp = call_arxiv_url(config, good_url)
puts "HTTP STATUS: #{resp.status}"

good_atom = resp.to_s
good_parsed = parse_arxiv_atom(good_atom)

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
bad_url = arxiv_api_path('querty?search_query=all:foo') # typo: "querty"
arxiv_response[bad_url] = call_arxiv_url(config, bad_url)
arxiv_response[bad_url].to_s # ensure body is fully read

# -------------------------------------------------------------------
# Output
# -------------------------------------------------------------------
File.write('spec/fixtures/arxiv_results.yml', arxiv_results.to_yaml)