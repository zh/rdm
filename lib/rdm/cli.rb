# frozen_string_literal: true

require "thor"

module Rdm
  class CLI < Thor
    class_option :debug, type: :boolean, default: false, desc: "Enable debug output"
    class_option :format, type: :string, enum: %w[json table csv], desc: "Output format"
    class_option :profile, type: :string, desc: "Config profile"

    def self.exit_on_failure?
      true
    end

    # --- Top-level commands ---

    desc "login", "Authenticate with a Redmine instance"
    option :url, type: :string
    option :api_key, type: :string
    option :api_key_stdin, type: :boolean, default: false
    option :allow_insecure_http, type: :boolean, default: false
    def login
      Commands::Login.new([], options).call
    end

    desc "logout", "Clear stored credentials"
    def logout
      Commands::Logout.new([], options).call
    end

    desc "status", "Show connection info"
    def status
      Commands::Status.new([], options).call
    end

    desc "open ISSUE_ID", "Open an issue in the browser"
    def open(issue_id)
      Commands::Open.new([], options).call(issue_id)
    end

    # --- Resource subcommands ---

    desc "projects SUBCOMMAND", "Manage projects"
    subcommand "projects", Commands::Projects

    desc "issues SUBCOMMAND", "Manage issues"
    subcommand "issues", Commands::Issues

    desc "time SUBCOMMAND", "Manage time entries"
    subcommand "time", Commands::TimeEntries

    desc "users SUBCOMMAND", "Manage users"
    subcommand "users", Commands::Users

    desc "versions SUBCOMMAND", "Manage versions"
    subcommand "versions", Commands::Versions

    desc "memberships SUBCOMMAND", "Manage project memberships"
    subcommand "memberships", Commands::Memberships

    desc "groups SUBCOMMAND", "Manage groups"
    subcommand "groups", Commands::Groups

    desc "queries SUBCOMMAND", "Manage saved queries"
    subcommand "queries", Commands::Queries

    desc "custom-fields SUBCOMMAND", "Manage custom fields"
    subcommand "custom-fields", Commands::CustomFields

    # --- Reference data (top-level for convenience) ---

    desc "trackers", "List trackers"
    def trackers
      Commands::Reference.new([], options).trackers
    end

    desc "statuses", "List issue statuses"
    def statuses
      Commands::Reference.new([], options).statuses
    end

    desc "priorities", "List issue priorities"
    def priorities
      Commands::Reference.new([], options).priorities
    end

    desc "activities", "List time entry activities"
    def activities
      Commands::Reference.new([], options).activities
    end

    desc "roles", "List roles"
    def roles
      Commands::Reference.new([], options).roles
    end

    desc "search QUERY", "Search Redmine"
    option :project_id, type: :string
    option :type, type: :string
    option :limit, type: :numeric, default: 25
    option :offset, type: :numeric, default: 0
    def search(query)
      Commands::Reference.new([], options).search(query)
    end

    # --- Aliases ---

    desc "me", "Show current user info"
    def me
      Commands::Users.new([], options).show("me")
    end

    desc "log", "Log time (shortcut for `rdm time log`)"
    option :hours, type: :numeric, required: true
    option :activity_id, type: :numeric, required: true
    option :issue_id, type: :numeric
    option :project_id, type: :string
    option :spent_on, type: :string
    option :comments, type: :string
    def log
      Commands::TimeEntries.new([], options).log
    end

    # Map single-letter aliases
    map "i" => :issues
    map "p" => :projects
    map "t" => :time
    map "u" => :users
  end
end
