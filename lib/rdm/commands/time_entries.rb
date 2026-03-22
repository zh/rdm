# frozen_string_literal: true

module Rdm
  module Commands
    class TimeEntries < Base
      namespace "time"

      LIST_COLUMNS = %w[id project issue user activity hours comments spent_on].freeze
      DETAIL_FIELDS = %w[id project issue user activity hours comments spent_on created_on updated_on].freeze

      desc "list", "List time entries"
      option :user_id, type: :numeric
      option :project_id, type: :string
      option :issue_id, type: :numeric
      option :from, type: :string, desc: "Start date (YYYY-MM-DD)"
      option :to, type: :string, desc: "End date (YYYY-MM-DD)"
      option :spent_on, type: :string, desc: "Exact date (YYYY-MM-DD)"
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def list
        params = {}
        params[:user_id] = options[:user_id] if options[:user_id]
        params[:project_id] = options[:project_id] if options[:project_id]
        params[:issue_id] = options[:issue_id] if options[:issue_id]
        params[:from] = options[:from] if options[:from]
        params[:to] = options[:to] if options[:to]
        params[:spent_on] = options[:spent_on] if options[:spent_on]
        params[:limit] = options[:limit]
        params[:offset] = options[:offset]

        result = client.get("/time_entries", params)
        output(result["time_entries"] || [], columns: LIST_COLUMNS)
      end

      desc "show ID", "Show time entry details"
      def show(id)
        result = client.get("/time_entries/#{id}")
        output_detail(result["time_entry"] || result, fields: DETAIL_FIELDS)
      end

      desc "log", "Log a time entry"
      option :hours, type: :numeric, required: true
      option :activity_id, type: :numeric, required: true
      option :issue_id, type: :numeric
      option :project_id, type: :string
      option :spent_on, type: :string, desc: "Date (YYYY-MM-DD), defaults to today"
      option :comments, type: :string
      option :custom_fields, type: :string, desc: "JSON array"
      def log
        unless options[:issue_id] || options[:project_id]
          $stderr.puts "Either --issue-id or --project-id is required."
          exit 4
        end

        data = {
          hours: options[:hours],
          activity_id: options[:activity_id]
        }
        data[:issue_id] = options[:issue_id] if options[:issue_id]
        data[:project_id] = options[:project_id] if options[:project_id]
        data[:spent_on] = options[:spent_on] if options[:spent_on]
        data[:comments] = options[:comments] if options[:comments]
        data[:custom_fields] = JSON.parse(options[:custom_fields]) if options[:custom_fields]

        result = client.post("/time_entries", { time_entry: data })
        output_detail(result["time_entry"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update a time entry"
      option :hours, type: :numeric
      option :activity_id, type: :numeric
      option :comments, type: :string
      option :spent_on, type: :string
      def update(id)
        data = {}
        %i[hours activity_id comments spent_on].each do |field|
          data[field] = options[field] if options[field]
        end

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/time_entries/#{id}", { time_entry: data })
        if result.empty?
          result = client.get("/time_entries/#{id}")
        end
        output_detail(result["time_entry"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a time entry"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("delete time entry ##{id}")
        client.delete("/time_entries/#{id}")
        puts "Deleted time entry ##{id}"
      end

      desc "bulk-log", "Bulk log time entries from JSON file"
      option :file, type: :string, required: true, desc: "Path to JSON file with entries array"
      def bulk_log
        file_path = options[:file]
        unless File.exist?(file_path)
          $stderr.puts "File not found: #{file_path}"
          exit 1
        end

        entries = JSON.parse(File.read(file_path))
        unless entries.is_a?(Array)
          $stderr.puts "JSON file must contain an array of time entry objects."
          exit 4
        end

        result = client.post("/extended_api/time_entries/bulk_create", { time_entries: entries })
        output(result, columns: nil)
      end
    end
  end
end
