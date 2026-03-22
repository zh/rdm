# frozen_string_literal: true

require "bundler/setup"
require "rspec"
require "webmock/rspec"
require "json"

# Load the gem
require_relative "../lib/rdm"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  # Block all external connections
  WebMock.disable_net_connect!

  config.before do
    WebMock.reset!
  end

  # Helper to stub Redmine API requests
  config.include(Module.new {
    def stub_redmine(method, path, status: 200, body: nil, headers: {})
      response_headers = { "Content-Type" => "application/json" }.merge(headers)
      response_body = body.is_a?(Hash) || body.is_a?(Array) ? body.to_json : body

      stub_request(method, "#{test_base_url}#{path}")
        .to_return(status: status, body: response_body, headers: response_headers)
    end

    def test_base_url
      "https://redmine.example.com"
    end

    def test_api_key
      "test_api_key_12345678"
    end

    def build_test_client
      Rdm::Client.new(base_url: test_base_url, api_key: test_api_key, timeout: 5)
    end
  })
end
