# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

# Post-process SimpleCov results to replace null values with 0
SimpleCov.at_exit do
  SimpleCov.result.format!

  coverage_file = 'coverage/.resultset.json'
  if File.exist?(coverage_file)
    data = JSON.parse(File.read(coverage_file))

    data.each do |_, coverage|
      coverage['coverage'].each do |_file, details|
        details['lines'].map! { |line| line.nil? ? 0 : line }
      end
    end

    File.write(coverage_file, JSON.pretty_generate(data))
  end
end

require 'dotenv'

Dotenv.load('/tmp/.timet/.env')

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'timet'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
