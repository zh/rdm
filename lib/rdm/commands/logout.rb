# frozen_string_literal: true

module Rdm
  module Commands
    class Logout < Base
      namespace "logout"

      def self.banner(command, namespace = nil, subcommand = false)
        "rdm logout"
      end

      desc "logout", "Clear stored credentials"
      def call
        cfg = config

        unless cfg.configured?
          puts "No credentials to clear for profile '#{cfg.profile_name}'."
          return
        end

        cfg.clear_profile
        puts "Logged out from profile '#{cfg.profile_name}'."
        puts "Note: The API key is still valid on the Redmine server. Regenerate it at /my/account if compromised."
      end

      default_task :call
    end
  end
end
