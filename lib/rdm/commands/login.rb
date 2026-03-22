# frozen_string_literal: true

require "uri"
require "io/console"

module Rdm
  module Commands
    class Login < Thor
      namespace "login"

      # Make this invocable as a top-level command, not a subcommand
      def self.banner(command, namespace = nil, subcommand = false)
        "rdm login"
      end

      desc "login", "Authenticate with a Redmine instance"
      option :url, type: :string, desc: "Redmine URL"
      option :api_key, type: :string, desc: "API key (insecure on workstations — prefer --api-key-stdin)"
      option :api_key_stdin, type: :boolean, default: false, desc: "Read API key from stdin"
      option :profile, type: :string, desc: "Profile name to save as"
      option :allow_insecure_http, type: :boolean, default: false, desc: "Allow HTTP (non-HTTPS) URLs"

      def self.exit_on_failure?
        true
      end

      def call
        url = resolve_url
        api_key = resolve_api_key

        # Validate URL
        validate_url!(url)
        enforce_https!(url) unless options[:allow_insecure_http]

        # Test connection
        $stderr.puts "Connecting to #{url}..."
        test_client = Rdm::Client.new(base_url: url, api_key: api_key, timeout: 15)

        begin
          user = test_client.test_connection
        rescue Rdm::AuthError
          $stderr.puts "Invalid API key. Check your key at #{url}/my/account"
          exit 2
        rescue Rdm::ConnectionError => e
          $stderr.puts "Cannot connect to #{url}. Check the URL and try again."
          $stderr.puts "  #{e.message}"
          exit 1
        rescue Rdm::Error => e
          $stderr.puts "Login failed: #{e.message}"
          exit 1
        end

        # Save to config
        cfg = Rdm::Config.load(profile: options[:profile])
        cfg.save_profile(
          url: url,
          api_key: api_key,
          user_id: user&.fetch("id", nil),
          user_login: user&.fetch("login", nil),
          user_name: [user&.fetch("firstname", nil), user&.fetch("lastname", nil)].compact.join(" ")
        )

        name = [user&.fetch("firstname", nil), user&.fetch("lastname", nil)].compact.join(" ")
        login = user&.fetch("login", nil)
        puts "Logged in as #{name} (#{login}) at #{url}"
      end

      default_task :call

      private

      def resolve_url
        if options[:url]
          options[:url]
        elsif $stdin.tty?
          $stderr.print "Redmine URL: "
          $stdin.gets&.strip
        else
          $stderr.puts "No URL provided. Use --url or run interactively."
          exit 1
        end
      end

      def resolve_api_key
        if options[:api_key_stdin]
          key = $stdin.read.strip
          if key.empty?
            $stderr.puts "No API key received on stdin."
            exit 1
          end
          key
        elsif options[:api_key]
          options[:api_key]
        elsif $stdin.tty?
          $stderr.print "API Key (find at /my/account): "
          key = $stdin.noecho(&:gets)&.strip
          $stderr.puts # newline after hidden input
          key
        else
          $stderr.puts "No API key provided. Use --api-key, --api-key-stdin, or run interactively."
          exit 1
        end
      end

      def validate_url!(url)
        uri = URI.parse(url)
        unless %w[http https].include?(uri.scheme)
          $stderr.puts "Invalid URL scheme '#{uri.scheme}'. Only http and https are allowed."
          exit 1
        end
      rescue URI::InvalidURIError => e
        $stderr.puts "Invalid URL: #{e.message}"
        exit 1
      end

      def enforce_https!(url)
        return unless url.start_with?("http://")

        $stderr.puts "Refusing to store HTTP URL. Your API key would be sent in cleartext."
        $stderr.puts "Use --allow-insecure-http to override (not recommended)."
        exit 1
      end
    end
  end
end
