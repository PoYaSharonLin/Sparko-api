# frozen_string_literal: true

require 'open3'
require 'json'
require 'minitest/autorun'

describe 'Dimension Reduction Service (reducer.py)' do
  let(:python_script_path) do
    File.expand_path('../../../../app/domain/clustering/services/dimension_reducer.py', __dir__)
  end

  before do
    skip "reducer.py not found at #{python_script_path}" unless File.exist?(python_script_path)
  end

  def run_python_script(input_data)
    Open3.capture3("python3 #{python_script_path}", stdin_data: JSON.dump(input_data))
  end

  describe 'reduce_dimension function' do
    it 'HAPPY: returns empty list for empty input' do
      stdout_str, stderr_str, status = run_python_script([])

      _(stderr_str).must_be_empty
      _(status.success?).must_equal true

      result = JSON.parse(stdout_str)
      _(result).must_equal []
    end

    it 'HAPPY: returns the first two elements for a single high-dimensional vector' do
      embedding = [0.1, 0.2, 0.3, 0.4, 0.5]
      stdout_str, stderr_str, status = run_python_script(embedding)

      _(stderr_str).must_be_empty
      _(status.success?).must_equal true

      result = JSON.parse(stdout_str)
      _(result).must_equal [0.1, 0.2]
    end

    it 'HAPPY: returns the first two elements for a list containing a single high-dimensional vector' do
      embedding = [[0.1, 0.2, 0.3, 0.4, 0.5]]
      stdout_str, stderr_str, status = run_python_script(embedding)

      _(stderr_str).must_be_empty
      _(status.success?).must_equal true

      result = JSON.parse(stdout_str)
      _(result).must_equal [[0.1, 0.2]]
    end

    it 'HAPPY: uses PCA for 2 to 5 vectors' do
      embeddings = [
        [0.1, 0.2, 0.3],
        [0.4, 0.5, 0.6]
      ]
      stdout_str, stderr_str, status = run_python_script(embeddings)

      _(stderr_str).must_be_empty
      _(status.success?).must_equal true

      result = JSON.parse(stdout_str)
      _(result).must_be_instance_of Array
      _(result.length).must_equal 2
      result.each do |vec|
        _(vec).must_be_instance_of Array
        _(vec.length).must_equal 2
        vec.each { |val| _(val).must_be_kind_of Numeric }
      end
    end

    it 'HAPPY: uses t-SNE for more than 5 vectors' do
      embeddings = Array.new(10) { Array.new(5) { rand } }
      stdout_str, stderr_str, status = run_python_script(embeddings)

      _(stderr_str).must_be_empty
      _(status.success?).must_equal true

      result = JSON.parse(stdout_str)
      _(result).must_be_instance_of Array
      _(result.length).must_equal 10 # Ten 2D vectors
      result.each do |vec|
        _(vec).must_be_instance_of Array
        _(vec.length).must_equal 2
        vec.each { |val| _(val).must_be_kind_of Numeric }
      end
    end

    it 'SAD: exits with error code and prints to stderr on invalid JSON input' do
      _, stderr_str, status = Open3.capture3(
        "python3 #{python_script_path}",
        stdin_data: 'this is not json'
      )

      _(status.success?).must_equal false
      _(stderr_str).wont_be_empty
      _(stderr_str).must_match(/Error decoding JSON/)
    end
  end
end
