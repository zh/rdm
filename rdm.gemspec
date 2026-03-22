# frozen_string_literal: true

require_relative "lib/rdm/version"

Gem::Specification.new do |spec|
  spec.name = "rdm"
  spec.version = Rdm::VERSION
  spec.authors = ["Agileware"]
  spec.email = ["info@agileware.io"]

  spec.summary = "A command-line interface for Redmine"
  spec.description = "rdm is a CLI tool for interacting with Redmine instances via the REST API. " \
                     "Manage issues, projects, time entries, users, and more from the terminal."
  spec.homepage = "https://github.com/agileware/rdm"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    Dir["{bin,lib}/**/*", "LICENSE", "README.md"]
  end
  spec.bindir = "bin"
  spec.executables = ["rdm"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.57"
  spec.add_development_dependency "webmock", "~> 3.19"
end
