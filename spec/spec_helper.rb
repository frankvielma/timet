# frozen_string_literal: true

require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true  # Ensure a single lcov.info file
SimpleCov::Formatter::LcovFormatter.config.output_directory = 'coverage'   # Save it in coverage/
SimpleCov::Formatter::LcovFormatter.config.output_name = 'lcov.info'       # Ensure correct filename

SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start

puts 'LCOV output enabled. Coverage files will be stored in coverage/lcov.info.'

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
