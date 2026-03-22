# frozen_string_literal: true

require "thor"

module Rdm
  module Commands
    # Base class for all resource subcommands.
    # Provides client, config, and output helpers.
    class Base < Thor
      class_option :format, type: :string, enum: %w[json table csv], desc: "Output format"
      class_option :profile, type: :string, desc: "Config profile to use"
      class_option :debug, type: :boolean, default: false, desc: "Enable debug output"

      # Thor error handling — exit with proper codes
      def self.exit_on_failure?
        true
      end

      no_commands do
        def client
          @client ||= begin
            cfg = config
            unless cfg.configured?
              $stderr.puts "Not logged in. Run `rdm login` first."
              exit 2
            end

            if cfg.http_url?
              $stderr.puts "WARNING: Communicating over unencrypted HTTP. Your API key is exposed."
            end

            Rdm::Client.new(
              base_url: cfg.url,
              api_key: cfg.api_key,
              timeout: cfg.timeout,
              debug: options[:debug] || ENV["RDM_DEBUG"] == "1"
            )
          end
        end

        def config
          @config ||= Rdm::Config.load(profile: options[:profile])
        end

        def output(data, columns: nil)
          fmt = resolve_format
          puts Rdm::Formatter.output(data, format: fmt, columns: columns)
        end

        def output_detail(data, fields: nil)
          fmt = resolve_format
          if fmt == :json
            puts Rdm::Formatter.output(data, format: :json)
          else
            puts Rdm::Formatter.detail(data, fields: fields)
          end
        end

        def resolve_format
          if options[:format]
            options[:format].to_sym
          else
            Rdm::Formatter.auto_format
          end
        end

        def require_confirm!(action)
          unless options[:confirm]
            $stderr.puts "This will #{action}. Pass --confirm to proceed."
            exit 4
          end
        end
      end
    end
  end
end
