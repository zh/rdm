# frozen_string_literal: true

module Rdm
  module Commands
    class Issues < Base
      namespace "issues"

      LIST_COLUMNS = %w[id tracker status priority subject assigned_to updated_on].freeze
      DETAIL_FIELDS = %w[
        id project tracker status priority author assigned_to subject description
        start_date due_date done_ratio estimated_hours spent_hours
        created_on updated_on closed_on fixed_version parent category
      ].freeze

      # --- List ---
      desc "list", "List issues"
      option :project_id, type: :string
      option :tracker_id, type: :numeric
      option :status, type: :string, default: "open", desc: "open, closed, *, or status ID"
      option :assigned_to_id, type: :numeric
      option :query_id, type: :numeric
      option :sort, type: :string, desc: "e.g. updated_on:desc"
      option :include, type: :string, desc: "attachments,relations,journals,watchers"
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def list
        params = {}
        params[:project_id] = options[:project_id] if options[:project_id]
        params[:tracker_id] = options[:tracker_id] if options[:tracker_id]
        params[:status_id] = options[:status] if options[:status]
        params[:assigned_to_id] = options[:assigned_to_id] if options[:assigned_to_id]
        params[:query_id] = options[:query_id] if options[:query_id]
        params[:sort] = options[:sort] if options[:sort]
        params[:include] = options[:include] if options[:include]
        params[:limit] = options[:limit]
        params[:offset] = options[:offset]

        result = client.get("/issues", params)
        output(result["issues"] || [], columns: LIST_COLUMNS)
      end

      # --- Show ---
      desc "show ID", "Show issue details"
      option :include, type: :string, desc: "attachments,relations,changesets,journals,watchers"
      def show(id)
        params = {}
        params[:include] = options[:include] if options[:include]
        result = client.get("/issues/#{id}", params)
        output_detail(result["issue"] || result, fields: DETAIL_FIELDS)
      end

      # --- Create ---
      desc "create", "Create a new issue"
      option :project_id, type: :string, required: true
      option :tracker_id, type: :numeric, required: true
      option :subject, type: :string, required: true
      option :status_id, type: :numeric
      option :priority_id, type: :numeric
      option :description, type: :string
      option :assigned_to_id, type: :numeric
      option :parent_issue_id, type: :numeric
      option :estimated_hours, type: :numeric
      option :done_ratio, type: :numeric
      option :start_date, type: :string
      option :due_date, type: :string
      option :watcher_ids, type: :string, desc: "Comma-separated user IDs"
      option :custom_fields, type: :string, desc: "JSON array of custom field values"
      def create
        data = {
          project_id: options[:project_id],
          tracker_id: options[:tracker_id],
          subject: options[:subject]
        }
        %i[status_id priority_id description assigned_to_id parent_issue_id
           estimated_hours done_ratio start_date due_date].each do |field|
          data[field] = options[field] if options[field]
        end
        data[:watcher_user_ids] = options[:watcher_ids].split(",").map { |id| id.strip.to_i } if options[:watcher_ids]
        data[:custom_fields] = JSON.parse(options[:custom_fields]) if options[:custom_fields]

        result = client.post("/issues", { issue: data })
        output_detail(result["issue"] || result, fields: DETAIL_FIELDS)
      end

      # --- Update ---
      desc "update ID", "Update an existing issue"
      option :subject, type: :string
      option :status_id, type: :numeric
      option :priority_id, type: :numeric
      option :tracker_id, type: :numeric
      option :description, type: :string
      option :assigned_to_id, type: :numeric
      option :notes, type: :string, desc: "Add a journal note"
      option :private_notes, type: :boolean
      option :done_ratio, type: :numeric
      option :start_date, type: :string
      option :due_date, type: :string
      option :estimated_hours, type: :numeric
      option :fixed_version_id, type: :numeric
      option :parent_issue_id, type: :numeric
      option :custom_fields, type: :string, desc: "JSON array"
      def update(id)
        data = {}
        %i[subject status_id priority_id tracker_id description assigned_to_id
           notes done_ratio start_date due_date estimated_hours fixed_version_id parent_issue_id].each do |field|
          data[field] = options[field] if options[field]
        end
        data[:private_notes] = options[:private_notes] unless options[:private_notes].nil?
        data[:custom_fields] = JSON.parse(options[:custom_fields]) if options[:custom_fields]

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/issues/#{id}", { issue: data })
        if result.empty?
          result = client.get("/issues/#{id}")
        end
        output_detail(result["issue"] || result, fields: DETAIL_FIELDS)
      end

      # --- Delete ---
      desc "delete ID", "Delete an issue"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("permanently delete issue ##{id}")
        issue = client.get("/issues/#{id}")
        client.delete("/issues/#{id}")
        subject = issue.dig("issue", "subject") || id
        puts "Deleted issue ##{id}: #{subject}"
      end

      # --- Copy ---
      desc "copy ID", "Copy an issue to same or different project"
      option :project_id, type: :string, required: true, desc: "Target project"
      option :link, type: :boolean, default: false, desc: "Create copied_to relation"
      option :subject_prefix, type: :string, desc: "Prefix for copied subject"
      def copy(id)
        # Fetch source issue
        source_response = client.get("/issues/#{id}")
        source = source_response["issue"]

        # Build new issue data
        data = {
          project_id: options[:project_id],
          tracker_id: source.dig("tracker", "id"),
          subject: options[:subject_prefix] ? "#{options[:subject_prefix]}#{source["subject"]}" : source["subject"],
          description: source["description"]
        }
        data[:priority_id] = source.dig("priority", "id") if source["priority"]
        data[:assigned_to_id] = source.dig("assigned_to", "id") if source["assigned_to"]
        data[:category_id] = source.dig("category", "id") if source["category"]
        data[:fixed_version_id] = source.dig("fixed_version", "id") if source["fixed_version"]
        data[:estimated_hours] = source["estimated_hours"] if source["estimated_hours"]
        data[:done_ratio] = source["done_ratio"] if source["done_ratio"]

        result = client.post("/issues", { issue: data })
        new_issue = result["issue"] || result

        # Link if requested
        if options[:link] && new_issue["id"]
          begin
            client.post("/issues/#{id}/relations", {
              relation: { issue_to_id: new_issue["id"], relation_type: "copied_to" }
            })
          rescue Rdm::Error => e
            $stderr.puts "Warning: Could not create relation: #{e.message}"
          end
        end

        output_detail(new_issue, fields: DETAIL_FIELDS)
      end

      # --- Move ---
      desc "move ID", "Move issue to another project"
      option :project_id, type: :string, required: true
      option :tracker_id, type: :numeric
      def move(id)
        data = { project_id: options[:project_id] }
        data[:tracker_id] = options[:tracker_id] if options[:tracker_id]

        result = client.put("/issues/#{id}", { issue: data })
        if result.empty?
          result = client.get("/issues/#{id}")
        end
        output_detail(result["issue"] || result, fields: DETAIL_FIELDS)
      end

      # --- Watchers ---
      desc "add-watcher", "Add a watcher to an issue"
      option :issue_id, type: :numeric, required: true
      option :user_id, type: :numeric, required: true
      def add_watcher
        client.post("/issues/#{options[:issue_id]}/watchers", { user_id: options[:user_id] })
        puts "Added user #{options[:user_id]} as watcher on issue ##{options[:issue_id]}"
      end
      map "add-watcher" => :add_watcher

      desc "remove-watcher", "Remove a watcher from an issue"
      option :issue_id, type: :numeric, required: true
      option :user_id, type: :numeric, required: true
      def remove_watcher
        client.delete("/issues/#{options[:issue_id]}/watchers/#{options[:user_id]}")
        puts "Removed user #{options[:user_id]} from watchers on issue ##{options[:issue_id]}"
      end
      map "remove-watcher" => :remove_watcher

      # --- Relations ---
      desc "relations ID", "List relations for an issue"
      def relations(id)
        result = client.get("/issues/#{id}/relations")
        output(result["relations"] || [], columns: %w[id issue_id issue_to_id relation_type delay])
      end

      desc "add-relation", "Create a relation between issues"
      option :issue_id, type: :numeric, required: true
      option :issue_to_id, type: :numeric, required: true
      option :type, type: :string, required: true, desc: "relates,duplicates,blocks,precedes,follows,copied_to,copied_from"
      option :delay, type: :numeric
      def add_relation
        data = {
          issue_to_id: options[:issue_to_id],
          relation_type: options[:type]
        }
        data[:delay] = options[:delay] if options[:delay]

        result = client.post("/issues/#{options[:issue_id]}/relations", { relation: data })
        puts "Created #{options[:type]} relation from ##{options[:issue_id]} to ##{options[:issue_to_id]}"
      end
      map "add-relation" => :add_relation

      desc "delete-relation", "Delete a relation"
      option :relation_id, type: :numeric, required: true
      option :confirm, type: :boolean, default: false
      def delete_relation
        require_confirm!("delete relation ##{options[:relation_id]}")
        client.delete("/relations/#{options[:relation_id]}")
        puts "Deleted relation ##{options[:relation_id]}"
      end
      map "delete-relation" => :delete_relation

      # --- Journals ---
      desc "journals ID", "Show journals (history) for an issue"
      def journals(id)
        result = client.get("/issues/#{id}", { include: "journals" })
        journals = result.dig("issue", "journals") || []
        if resolve_format == :json
          puts Rdm::Formatter.output(journals, format: :json)
        else
          journals.each do |j|
            user = j.dig("user", "name") || "Unknown"
            date = j["created_on"]
            puts "--- #{user} (#{date}) ---"
            puts j["notes"] if j["notes"] && !j["notes"].empty?
            (j["details"] || []).each do |d|
              puts "  #{d["name"]}: #{d["old_value"]} -> #{d["new_value"]}"
            end
            puts
          end
        end
      end
    end
  end
end
