# frozen_string_literal: true

require "yaml"
require "fileutils"
require "tempfile"

module Rdm
  class Config
    DEFAULT_DIR = File.join(Dir.home, ".rdm")
    DEFAULT_FILE = File.join(DEFAULT_DIR, "config.yml")
    DIR_MODE = 0o700
    FILE_MODE = 0o600

    DEFAULTS = {
      "format" => "table",
      "timeout" => 30,
      "color" => true,
      "page_size" => 25
    }.freeze

    attr_reader :profile_name

    class << self
      # Load config for a given profile, with env var overrides
      def load(profile: nil)
        config_path = ENV.fetch("RDM_CONFIG", DEFAULT_FILE)
        new(config_path, profile: profile)
      end

      # Create skeleton config directory and file if they don't exist
      def ensure_config_exists
        config_path = ENV.fetch("RDM_CONFIG", DEFAULT_FILE)
        dir = File.dirname(config_path)

        unless File.directory?(dir)
          FileUtils.mkdir_p(dir)
          File.chmod(DIR_MODE, dir)
        end

        return if File.exist?(config_path)

        skeleton = {
          "default_profile" => "default",
          "profiles" => {},
          "settings" => {
            "format" => "table",
            "timeout" => 30,
            "page_size" => 25
          }
        }

        tmp = Tempfile.new("rdm_config", dir)
        tmp.write(YAML.dump(skeleton))
        tmp.close
        File.chmod(FILE_MODE, tmp.path)
        File.rename(tmp.path, config_path)
      rescue StandardError # non-fatal — login will create it later
        nil
      end
    end

    def initialize(config_path, profile: nil)
      @config_path = config_path
      @data = load_file
      @profile_name = profile || ENV.fetch("RDM_PROFILE", nil) || @data.fetch("default_profile", "default")
    end

    # --- Accessors with env var override ---

    def url
      env_url = ENV.fetch("RDM_URL", nil)
      return env_url if env_url && !env_url.empty?

      profile.fetch("url", nil)
    end

    def api_key
      env_key = ENV.fetch("RDM_API_KEY", nil)
      return env_key if env_key && !env_key.empty?

      profile.fetch("api_key", nil)
    end

    def user_login
      profile.fetch("user_login", nil)
    end

    def user_name
      profile.fetch("user_name", nil)
    end

    def user_id
      profile.fetch("user_id", nil)
    end

    def timeout
      ENV.fetch("RDM_TIMEOUT", nil)&.to_i || settings.fetch("timeout", DEFAULTS["timeout"])
    end

    def default_format
      ENV.fetch("RDM_FORMAT", nil) || settings.fetch("format", DEFAULTS["format"])
    end

    def page_size
      settings.fetch("page_size", DEFAULTS["page_size"])
    end

    def color?
      settings.fetch("color", DEFAULTS["color"])
    end

    def configured?
      !!(url && api_key && !api_key.empty?)
    end

    def http_url?
      u = url
      u && u.start_with?("http://")
    end

    # --- Profile management ---

    def profile
      profiles = @data.fetch("profiles", {})
      profiles.fetch(@profile_name, {})
    end

    def settings
      @data.fetch("settings", {})
    end

    def profile_names
      @data.fetch("profiles", {}).keys
    end

    # Save credentials for current profile
    def save_profile(url:, api_key:, user_id: nil, user_login: nil, user_name: nil)
      @data["profiles"] ||= {}
      @data["profiles"][@profile_name] = {
        "url" => url,
        "api_key" => api_key,
        "user_id" => user_id,
        "user_login" => user_login,
        "user_name" => user_name
      }.compact
      @data["default_profile"] ||= @profile_name
      save_file
    end

    # Clear credentials for current profile (overwrite api_key before removing)
    def clear_profile
      if @data.dig("profiles", @profile_name, "api_key")
        @data["profiles"][@profile_name]["api_key"] = ""
      end
      @data["profiles"]&.delete(@profile_name)
      # If we deleted the default profile, update default
      if @data["default_profile"] == @profile_name
        remaining = @data.fetch("profiles", {}).keys.first
        @data["default_profile"] = remaining
      end
      save_file
    end

    # Mask an API key for display: show first 4 and last 4 chars
    def self.mask_key(key)
      return nil if key.nil? || key.empty?
      return "****" if key.length <= 8

      "#{key[0..3]}#{"*" * (key.length - 8)}#{key[-4..]}"
    end

    private

    def load_file
      return empty_config unless File.exist?(@config_path)

      check_permissions(@config_path)
      content = File.read(@config_path)
      data = YAML.safe_load(content, permitted_classes: [], permitted_symbols: [])
      data.is_a?(Hash) ? data : empty_config
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
      raise ConfigError, "Invalid config file #{@config_path}: #{e.message}"
    end

    def save_file
      dir = File.dirname(@config_path)
      ensure_directory(dir)

      # Atomic write: write to temp file with correct permissions, then rename
      tmp = Tempfile.new("rdm_config", dir)
      tmp.write(YAML.dump(@data))
      tmp.close
      File.chmod(FILE_MODE, tmp.path)
      File.rename(tmp.path, @config_path)
    rescue StandardError => e
      tmp&.close
      tmp&.unlink
      raise ConfigError, "Failed to save config: #{e.message}"
    end

    def ensure_directory(dir)
      return if File.directory?(dir)

      FileUtils.mkdir_p(dir)
      File.chmod(DIR_MODE, dir)
    end

    def check_permissions(path)
      return unless File.exist?(path)

      mode = File.stat(path).mode & 0o777
      return if mode & 0o077 == 0

      warn "WARNING: #{path} has insecure permissions (#{format("%04o", mode)}). Run: chmod 600 #{path}"
    end

    def empty_config
      { "profiles" => {}, "settings" => {} }
    end
  end
end
