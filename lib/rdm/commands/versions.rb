# frozen_string_literal: true

module Rdm
  module Commands
    class Versions < Base
      namespace "versions"

      LIST_COLUMNS = %w[id name status sharing due_date description].freeze
      DETAIL_FIELDS = %w[id project name status sharing due_date description created_on updated_on].freeze

      desc "list", "List versions for a project"
      option :project_id, type: :string, required: true
      def list
        result = client.get("/projects/#{options[:project_id]}/versions")
        output(result["versions"] || [], columns: LIST_COLUMNS)
      end

      desc "show ID", "Show version details"
      def show(id)
        result = client.get("/versions/#{id}")
        output_detail(result["version"] || result, fields: DETAIL_FIELDS)
      end

      desc "create", "Create a new version"
      option :project_id, type: :string, required: true
      option :name, type: :string, required: true
      option :status, type: :string, desc: "open, locked, closed"
      option :sharing, type: :string, desc: "none, descendants, hierarchy, tree, system"
      option :due_date, type: :string
      option :description, type: :string
      def create
        data = { name: options[:name] }
        data[:status] = options[:status] if options[:status]
        data[:sharing] = options[:sharing] if options[:sharing]
        data[:due_date] = options[:due_date] if options[:due_date]
        data[:description] = options[:description] if options[:description]

        result = client.post("/projects/#{options[:project_id]}/versions", { version: data })
        output_detail(result["version"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update a version"
      option :name, type: :string
      option :status, type: :string
      option :due_date, type: :string
      option :description, type: :string
      option :sharing, type: :string
      def update(id)
        data = {}
        %i[name status due_date description sharing].each do |f|
          data[f] = options[f] if options[f]
        end

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/versions/#{id}", { version: data })
        if result.empty?
          result = client.get("/versions/#{id}")
        end
        output_detail(result["version"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a version"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("delete version ##{id}")
        client.delete("/versions/#{id}")
        puts "Deleted version ##{id}"
      end
    end
  end
end
