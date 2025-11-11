# frozen_string_literal: true

# spec/domain/services/extractor_spec.rb
require 'open3'
require 'json'
require_relative '../../helpers/spec_helper'

describe 'Concept Extractor Service' do
  let(:summary_text) do
    <<-TEXT
      Natural language processing (NLP) is a subfield of linguistics,
      computer science, and artificial intelligence concerned with the
      interactions between computers and human language. Challenges in natural
      language processing frequently involve speech recognition and
      natural language understanding.
    TEXT
  end

  let(:python_script_path) do
    File.expand_path('../../../app/domain/clustering/services/extractor.py', __dir__)
  end

  it 'HAPPY: correctly extracts 1-3 gram concepts from text' do
    _(File.exist?(python_script_path)).must_equal true,
                                                  "Python script not found at #{python_script_path}"

    stdout_str, stderr_str, status = Open3.capture3("python3 #{python_script_path}", stdin_data: summary_text)

    _(stderr_str).must_be_empty "Python script returned an error: #{stderr_str}"

    _(status.success?).must_equal true

    concepts = JSON.parse(stdout_str)

    _(concepts).must_be_instance_of Array
    _(concepts.count).must_equal 10
    _(concepts).must_include 'natural language processing'
  end

  it 'SAD: should not include subgram in n-gram' do
    _(File.exist?(python_script_path)).must_equal true,
                                                  "Python script not found at #{python_script_path}"

    stdout_str, stderr_str, status = Open3.capture3("python3 #{python_script_path}", stdin_data: summary_text)

    _(stderr_str).must_be_empty "Python script returned an error: #{stderr_str}"

    _(status.success?).must_equal true

    concepts = JSON.parse(stdout_str)
    _(concepts).wont_include 'natural'
    _(concepts).wont_include 'language'
    _(concepts).wont_include 'processing'
    _(concepts).wont_include 'natural language'
  end
end
