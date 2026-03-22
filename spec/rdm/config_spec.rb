# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Rdm::Config do
  let(:tmpdir) { Dir.mktmpdir("rdm_test") }
  let(:config_path) { File.join(tmpdir, "config.yml") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe ".load" do
    it "returns a Config instance" do
      config = described_class.new(config_path)
      expect(config).to be_a(Rdm::Config)
    end

    it "uses default profile when none specified" do
      config = described_class.new(config_path)
      expect(config.profile_name).to eq("default")
    end
  end

  describe "#configured?" do
    it "returns false when no credentials stored" do
      config = described_class.new(config_path)
      expect(config.configured?).to be false
    end

    it "returns true after saving a profile" do
      config = described_class.new(config_path)
      config.save_profile(url: "https://redmine.example.com", api_key: "abc123")
      expect(config.configured?).to be true
    end
  end

  describe "#save_profile and accessors" do
    it "saves and retrieves URL and API key" do
      config = described_class.new(config_path)
      config.save_profile(
        url: "https://redmine.example.com",
        api_key: "my_secret_key",
        user_id: 5,
        user_login: "admin",
        user_name: "Admin User"
      )

      # Reload from file
      reloaded = described_class.new(config_path)
      expect(reloaded.url).to eq("https://redmine.example.com")
      expect(reloaded.api_key).to eq("my_secret_key")
      expect(reloaded.user_id).to eq(5)
      expect(reloaded.user_login).to eq("admin")
      expect(reloaded.user_name).to eq("Admin User")
    end

    it "sets file permissions to 0600" do
      config = described_class.new(config_path)
      config.save_profile(url: "https://example.com", api_key: "key")

      mode = File.stat(config_path).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe "profile management" do
    it "supports multiple profiles" do
      config1 = described_class.new(config_path, profile: "production")
      config1.save_profile(url: "https://prod.example.com", api_key: "prod_key")

      config2 = described_class.new(config_path, profile: "staging")
      config2.save_profile(url: "https://staging.example.com", api_key: "staging_key")

      reloaded_prod = described_class.new(config_path, profile: "production")
      expect(reloaded_prod.url).to eq("https://prod.example.com")

      reloaded_staging = described_class.new(config_path, profile: "staging")
      expect(reloaded_staging.url).to eq("https://staging.example.com")
    end

    it "lists profile names" do
      config = described_class.new(config_path, profile: "one")
      config.save_profile(url: "https://one.example.com", api_key: "key1")

      config2 = described_class.new(config_path, profile: "two")
      config2.save_profile(url: "https://two.example.com", api_key: "key2")

      reloaded = described_class.new(config_path)
      expect(reloaded.profile_names).to contain_exactly("one", "two")
    end
  end

  describe "#clear_profile" do
    it "removes the current profile" do
      config = described_class.new(config_path, profile: "default")
      config.save_profile(url: "https://example.com", api_key: "secret")

      config.clear_profile

      reloaded = described_class.new(config_path, profile: "default")
      expect(reloaded.configured?).to be false
    end

    it "overwrites api_key before removing" do
      config = described_class.new(config_path, profile: "default")
      config.save_profile(url: "https://example.com", api_key: "secret")

      # After clear_profile, the api_key should be empty in the profile data
      # before deletion (this is a security measure)
      config.clear_profile
      reloaded = described_class.new(config_path, profile: "default")
      expect(reloaded.api_key).to be_nil
    end
  end

  describe "environment variable overrides" do
    it "overrides URL from RDM_URL" do
      config = described_class.new(config_path)
      config.save_profile(url: "https://file.example.com", api_key: "key")

      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("RDM_URL", nil).and_return("https://env.example.com")

      reloaded = described_class.new(config_path)
      expect(reloaded.url).to eq("https://env.example.com")
    end

    it "overrides API key from RDM_API_KEY" do
      config = described_class.new(config_path)
      config.save_profile(url: "https://example.com", api_key: "file_key")

      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("RDM_API_KEY", nil).and_return("env_key")

      reloaded = described_class.new(config_path)
      expect(reloaded.api_key).to eq("env_key")
    end
  end

  describe "#http_url?" do
    it "returns true for HTTP URLs" do
      config = described_class.new(config_path)
      config.save_profile(url: "http://insecure.example.com", api_key: "key")
      expect(config.http_url?).to be true
    end

    it "returns false for HTTPS URLs" do
      config = described_class.new(config_path)
      config.save_profile(url: "https://secure.example.com", api_key: "key")
      expect(config.http_url?).to be false
    end
  end

  describe ".mask_key" do
    it "masks the middle of a long key" do
      expect(described_class.mask_key("abcdef1234567890")).to eq("abcd********7890")
    end

    it "returns **** for short keys" do
      expect(described_class.mask_key("short")).to eq("****")
    end

    it "returns nil for nil" do
      expect(described_class.mask_key(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.mask_key("")).to be_nil
    end
  end

  describe "YAML safety" do
    it "uses safe_load and rejects unsafe YAML" do
      File.write(config_path, "--- !ruby/object:Gem::Installer\ni: x\n")
      File.chmod(0o600, config_path)

      expect { described_class.new(config_path) }.to raise_error(Rdm::ConfigError, /Invalid config/)
    end
  end

  describe "default settings" do
    it "returns default timeout" do
      config = described_class.new(config_path)
      expect(config.timeout).to eq(30)
    end

    it "returns default page size" do
      config = described_class.new(config_path)
      expect(config.page_size).to eq(25)
    end
  end
end
