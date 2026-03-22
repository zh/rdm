# frozen_string_literal: true

module Rdm
  module Commands
    class Projects < Base
      namespace "projects"

      LIST_COLUMNS = %w[id name identifier status created_on].freeze
      DETAIL_FIELDS = %w[id name identifier description status is_public created_on updated_on parent homepage].freeze

      desc "list", "List projects"
      option :status, type: :string, desc: "Filter: active, archived, closed"
      option :include, type: :string, desc: "Comma-separated: trackers,issue_categories,enabled_modules"
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def list
        params = {}
        params[:status] = map_project_status(options[:status]) if options[:status]
        params[:include] = options[:include] if options[:include]
        params[:limit] = options[:limit]
        params[:offset] = options[:offset]
        result = client.get("/projects", params)
        output(result["projects"] || [], columns: LIST_COLUMNS)
      end

      desc "show ID", "Show project details"
      option :include, type: :string, desc: "Comma-separated: trackers,issue_categories,enabled_modules"
      def show(id)
        params = {}
        params[:include] = options[:include] if options[:include]
        result = client.get("/projects/#{id}", params)
        output_detail(result["project"] || result, fields: DETAIL_FIELDS)
      end

      desc "create", "Create a new project"
      option :name, type: :string, required: true
      option :identifier, type: :string, required: true
      option :description, type: :string
      option :is_public, type: :boolean
      option :parent_id, type: :numeric
      option :inherit_members, type: :boolean
      option :modules, type: :string, desc: "Comma-separated module names"
      option :tracker_ids, type: :string, desc: "Comma-separated tracker IDs"
      def create
        data = {
          name: options[:name],
          identifier: options[:identifier]
        }
        data[:description] = options[:description] if options[:description]
        data[:is_public] = options[:is_public] unless options[:is_public].nil?
        data[:parent_id] = options[:parent_id] if options[:parent_id]
        data[:inherit_members] = options[:inherit_members] unless options[:inherit_members].nil?
        data[:enabled_module_names] = options[:modules].split(",").map(&:strip) if options[:modules]
        data[:tracker_ids] = options[:tracker_ids].split(",").map { |id| id.strip.to_i } if options[:tracker_ids]

        result = client.post("/projects", { project: data })
        output_detail(result["project"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update an existing project"
      option :name, type: :string
      option :description, type: :string
      option :is_public, type: :boolean
      option :parent_id, type: :numeric
      option :modules, type: :string, desc: "Comma-separated module names"
      def update(id)
        data = {}
        data[:name] = options[:name] if options[:name]
        data[:description] = options[:description] if options[:description]
        data[:is_public] = options[:is_public] unless options[:is_public].nil?
        data[:parent_id] = options[:parent_id] if options[:parent_id]
        data[:enabled_module_names] = options[:modules].split(",").map(&:strip) if options[:modules]

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/projects/#{id}", { project: data })
        # PUT returns 204 with empty body; re-fetch
        if result.empty?
          result = client.get("/projects/#{id}")
        end
        output_detail(result["project"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a project"
      option :confirm, type: :boolean, default: false, desc: "Confirm deletion"
      def delete(id)
        require_confirm!("permanently delete project ##{id}")
        # Fetch details before delete for confirmation output
        project = client.get("/projects/#{id}")
        client.delete("/projects/#{id}")
        name = project.dig("project", "name") || id
        puts "Deleted project: #{name} (#{id})"
      end

      private

      def map_project_status(status)
        case status.to_s.downcase
        when "active" then 1
        when "closed" then 5
        when "archived" then 9
        else status
        end
      end
    end
  end
end
