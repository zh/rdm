# frozen_string_literal: true

module Rdm
  module Commands
    class Queries < Base
      namespace "queries"

      LIST_COLUMNS = %w[id name project is_public].freeze
      DETAIL_FIELDS = %w[id name project is_public visibility sort_criteria filters columns group_by].freeze

      desc "list", "List saved queries"
      option :project_id, type: :string
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def list
        params = { limit: options[:limit], offset: options[:offset] }
        params[:project_id] = options[:project_id] if options[:project_id]
        result = client.get("/queries", params)
        output(result["queries"] || [], columns: LIST_COLUMNS)
      end

      desc "create", "Create a saved query (requires Extended API plugin)"
      option :name, type: :string, required: true
      option :type, type: :string, default: "IssueQuery"
      option :visibility, type: :numeric, desc: "0=private, 1=roles, 2=public"
      option :project_id, type: :string
      option :filters, type: :string, desc: "JSON object of filters"
      option :columns, type: :string, desc: "Comma-separated column names"
      option :sort_criteria, type: :string, desc: "JSON array of sort criteria"
      option :group_by, type: :string
      def create
        data = { name: options[:name], type: options[:type] }
        data[:visibility] = options[:visibility] if options[:visibility]
        data[:project_id] = options[:project_id] if options[:project_id]
        data[:filters] = JSON.parse(options[:filters]) if options[:filters]
        data[:column_names] = options[:columns].split(",").map(&:strip) if options[:columns]
        data[:sort_criteria] = JSON.parse(options[:sort_criteria]) if options[:sort_criteria]
        data[:group_by] = options[:group_by] if options[:group_by]

        result = client.post("/extended_api/queries", { query: data })
        output_detail(result["query"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update a saved query (requires Extended API plugin)"
      option :name, type: :string
      option :filters, type: :string, desc: "JSON object"
      option :columns, type: :string, desc: "Comma-separated"
      def update(id)
        data = {}
        data[:name] = options[:name] if options[:name]
        data[:filters] = JSON.parse(options[:filters]) if options[:filters]
        data[:column_names] = options[:columns].split(",").map(&:strip) if options[:columns]

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/extended_api/queries/#{id}", { query: data })
        if result.empty?
          result = client.get("/queries/#{id}")
        end
        output_detail(result["query"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a saved query (requires Extended API plugin)"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("delete query ##{id}")
        client.delete("/extended_api/queries/#{id}")
        puts "Deleted query ##{id}"
      end
    end
  end
end
