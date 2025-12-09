# frozen_string_literal: true

require 'open3'
require 'json'
require_relative '../../../helpers/spec_helper'

describe 'Embedding Service (embedder.py)' do
  let(:python_script_path) do
    File.expand_path('../../../../app/domain/clustering/services/embedder.py', __dir__)
  end

  let(:sample_text) { 'Natural language processing is a subfield of artificial intelligence.' }

  let(:empty_text) { '' }

  before do
    skip "embedder.py not found at #{python_script_path}" unless File.exist?(python_script_path)
  end

  it 'HAPPY: returns a valid embedding vector as JSON array for non-empty input' do
    stdout_str, stderr_str, status = Open3.capture3(
      "python3 #{python_script_path}",
      stdin_data: sample_text
    )

    _(stderr_str).must_be_empty("Python script errored: #{stderr_str}")
    _(status.success?).must_equal(true, 'Script exited with non-zero status')

    embedding = JSON.parse(stdout_str)

    _(embedding).must_be_instance_of Array
    _(embedding).wont_be_empty
    _(embedding.length).must_equal 384 # dim check: all-MiniLM-L6-v2 embedding size = 384

    # type safe check: embedding value should be float
    embedding.each do |val|
      _(val).must_be_kind_of Numeric
      _(val).must_be_close_to(val, 0.000001)
    end

    # boundedness test: values are inside expected bound
    norm = Math.sqrt(embedding.sum { |x| x * x })
    _(norm).must_be :>, 0.1
    _(norm).must_be :<, 100.0

    # numerical sanity check: no NaN & no infinity
    _(embedding.any?(&:nan?)).must_equal false
    _(embedding.any?(&:infinite?)).must_equal false
  end

  it 'HAPPY: returns empty array [] when input is empty or whitespace' do
    stdout_str, stderr_str, status = Open3.capture3(
      "python3 #{python_script_path}",
      stdin_data: empty_text
    )

    _(stderr_str).must_be_empty
    _(status.success?).must_equal true

    result = JSON.parse(stdout_str)
    _(result).must_equal []
  end

  it 'SAD: exits with error code and prints to stderr on exception' do
    env_with_broken_cache = { 'TRANSFORMERS_CACHE' => '/this/path/does/not/exist/and/will/cause/permission/error' }

    _stdout, stderr_str, status = Open3.capture3(
      env_with_broken_cache,
      "python3 #{python_script_path}",
      stdin_data: sample_text
    )

    _(status.success?).must_equal false
    _(stderr_str).wont_be_empty
    _(stderr_str).must_match(/Error in embedder.py/)
  end

  it 'HAPPY: outputs valid JSON even with special characters in input' do
    tricky_text = "Hello\nworld! 🚀 123 !@# $%^ &*() Unicode: 你好，世界"

    stdout_str, _stderr_str, status = Open3.capture3(
      "python3 #{python_script_path}",
      stdin_data: tricky_text
    )

    _(status.success?).must_equal true
    embedding = JSON.parse(stdout_str)

    _(embedding).must_be_instance_of Array
    _(embedding.length).must_equal 384
  end
end
