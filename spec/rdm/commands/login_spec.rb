# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Rdm::Commands::Login do
  let(:tmpdir) { Dir.mktmpdir("rdm_test") }
  let(:config_path) { File.join(tmpdir, "config.yml") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("RDM_CONFIG", anything).and_return(config_path)
    allow(ENV).to receive(:fetch).with("RDM_DEBUG", anything).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("RDM_DEBUG").and_return(nil)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "successful login" do
    it "validates credentials and saves config" do
      stub_request(:get, "https://redmine.example.com/users/current.json")
        .to_return(status: 200, body: {
          "user" => {
            "id" => 1, "login" => "admin",
            "firstname" => "Admin", "lastname" => "User"
          }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        url: "https://redmine.example.com",
        api_key: "valid_key",
        profile: nil,
        allow_insecure_http: false,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to output(/Logged in as Admin User/).to_stdout

      # Verify config was saved
      config = Rdm::Config.new(config_path)
      expect(config.url).to eq("https://redmine.example.com")
      expect(config.api_key).to eq("valid_key")
    end
  end

  describe "failed login" do
    it "exits with code 2 on invalid API key" do
      stub_request(:get, "https://redmine.example.com/users/current.json")
        .to_return(status: 401, body: { "error" => "Unauthorized" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        url: "https://redmine.example.com",
        api_key: "bad_key",
        profile: nil,
        allow_insecure_http: false,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(2)
      end
    end

    it "exits with code 1 on connection failure" do
      stub_request(:get, "https://unreachable.example.com/users/current.json")
        .to_raise(Faraday::ConnectionFailed.new("refused"))

      cmd = described_class.new([], {
        url: "https://unreachable.example.com",
        api_key: "key",
        profile: nil,
        allow_insecure_http: false,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    end
  end

  describe "HTTPS enforcement" do
    it "rejects HTTP URLs without --allow-insecure-http" do
      cmd = described_class.new([], {
        url: "http://insecure.example.com",
        api_key: "key",
        profile: nil,
        allow_insecure_http: false,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    end

    it "allows HTTP URLs with --allow-insecure-http" do
      stub_request(:get, "http://insecure.example.com/users/current.json")
        .to_return(status: 200, body: {
          "user" => { "id" => 1, "login" => "admin", "firstname" => "Admin", "lastname" => "User" }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        url: "http://insecure.example.com",
        api_key: "key",
        profile: nil,
        allow_insecure_http: true,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to output(/Logged in/).to_stdout
    end
  end

  describe "URL validation" do
    it "rejects invalid URL schemes" do
      cmd = described_class.new([], {
        url: "ftp://bad.example.com",
        api_key: "key",
        profile: nil,
        allow_insecure_http: false,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    end
  end

  describe "profile support" do
    it "saves to named profile" do
      stub_request(:get, "https://staging.example.com/users/current.json")
        .to_return(status: 200, body: {
          "user" => { "id" => 2, "login" => "dev", "firstname" => "Dev", "lastname" => "User" }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        url: "https://staging.example.com",
        api_key: "staging_key",
        profile: "staging",
        allow_insecure_http: false,
        api_key_stdin: false,
        debug: false
      })

      expect { cmd.call }.to output(/Logged in/).to_stdout

      config = Rdm::Config.new(config_path, profile: "staging")
      expect(config.url).to eq("https://staging.example.com")
    end
  end
end
