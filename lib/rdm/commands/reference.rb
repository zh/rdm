# frozen_string_literal: true

module Rdm
  module Commands
    class Reference < Base
      namespace "reference"

      desc "trackers", "List trackers"
      def trackers
        result = client.get("/trackers")
        output(result["trackers"] || [], columns: %w[id name default_status])
      end

      desc "statuses", "List issue statuses"
      def statuses
        result = client.get("/issue_statuses")
        output(result["issue_statuses"] || [], columns: %w[id name is_closed])
      end

      desc "priorities", "List issue priorities"
      def priorities
        result = client.get("/enumerations/issue_priorities")
        output(result["issue_priorities"] || [], columns: %w[id name is_default active])
      end

      desc "activities", "List time entry activities"
      def activities
        result = client.get("/enumerations/time_entry_activities")
        output(result["time_entry_activities"] || [], columns: %w[id name is_default active])
      end

      desc "roles", "List roles"
      def roles
        result = client.get("/roles")
        output(result["roles"] || [], columns: %w[id name])
      end

      desc "search QUERY", "Search Redmine"
      option :project_id, type: :string
      option :type, type: :string, desc: "issues, wiki, news, etc."
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def search(query)
        params = { q: query, limit: options[:limit], offset: options[:offset] }
        params[:project_id] = options[:project_id] if options[:project_id]
        params[:type] = options[:type] if options[:type]

        # Redmine search endpoint uses a special path when project-scoped
        result = client.get("/search", params)
        output(result["results"] || [], columns: %w[id title type url description])
      end
    end
  end
end
