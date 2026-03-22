# frozen_string_literal: true

module Rdm
  module Commands
    class Open < Base
      namespace "open"

      def self.banner(command, namespace = nil, subcommand = false)
        "rdm open ISSUE_ID"
      end

      desc "open ISSUE_ID", "Open an issue in the browser"
      def call(issue_id)
        cfg = config
        unless cfg.configured?
          $stderr.puts "Not logged in. Run `rdm login` first."
          exit 2
        end

        url = "#{cfg.url}/issues/#{issue_id}"

        # Open in browser using platform-appropriate command
        opener = case RUBY_PLATFORM
                 when /darwin/  then "open"
                 when /linux/   then "xdg-open"
                 when /mingw|mswin/ then "start"
                 else
                   $stderr.puts "Cannot detect browser command for platform: #{RUBY_PLATFORM}"
                   exit 1
                 end

        system(opener, url)
      end

      default_task :call
    end
  end
end
