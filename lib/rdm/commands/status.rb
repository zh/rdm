# frozen_string_literal: true

module Rdm
  module Commands
    class Status < Base
      namespace "status"

      def self.banner(command, namespace = nil, subcommand = false)
        "rdm status"
      end

      desc "status", "Show connection info"
      def call
        cfg = config

        unless cfg.configured?
          $stderr.puts "Not configured. Run `rdm login` first."
          exit 2
        end

        puts "Profile:  #{cfg.profile_name}"
        puts "URL:      #{cfg.url}"
        puts "User:     #{cfg.user_name} (#{cfg.user_login})" if cfg.user_name
        puts "API Key:  #{Rdm::Config.mask_key(cfg.api_key)}"

        if cfg.http_url?
          $stderr.puts "WARNING: Using unencrypted HTTP connection."
        end

        # Try to verify connection
        begin
          user = client.test_connection
          puts "Status:   Connected"
          if user
            login = user.fetch("login", nil)
            name = [user.fetch("firstname", nil), user.fetch("lastname", nil)].compact.join(" ")
            puts "Server:   Logged in as #{name} (#{login})"
          end
        rescue Rdm::Error => e
          puts "Status:   Error — #{e.message}"
        end
      end

      default_task :call
    end
  end
end
