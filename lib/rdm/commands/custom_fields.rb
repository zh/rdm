# frozen_string_literal: true

module Rdm
  module Commands
    class CustomFields < Base
      namespace "custom-fields"

      LIST_COLUMNS = %w[id name field_format type is_required is_for_all].freeze
      DETAIL_FIELDS = %w[id name field_format type is_required is_for_all possible_values trackers searchable visible default_value].freeze

      desc "list", "List custom fields"
      def list
        result = client.get("/custom_fields")
        output(result["custom_fields"] || [], columns: LIST_COLUMNS)
      end

      desc "create", "Create a custom field (requires Extended API plugin)"
      option :name, type: :string, required: true
      option :field_format, type: :string, required: true, desc: "string, text, int, float, list, date, bool, user, version, link"
      option :type, type: :string, default: "IssueCustomField"
      option :is_required, type: :boolean
      option :is_for_all, type: :boolean
      option :possible_values, type: :string, desc: "Comma-separated values (for list format)"
      option :tracker_ids, type: :string, desc: "Comma-separated tracker IDs"
      option :searchable, type: :boolean
      option :visible, type: :boolean
      option :default_value, type: :string
      def create
        data = {
          name: options[:name],
          field_format: options[:field_format],
          type: options[:type]
        }
        data[:is_required] = options[:is_required] unless options[:is_required].nil?
        data[:is_for_all] = options[:is_for_all] unless options[:is_for_all].nil?
        data[:possible_values] = options[:possible_values].split(",").map(&:strip) if options[:possible_values]
        data[:tracker_ids] = options[:tracker_ids].split(",").map { |id| id.strip.to_i } if options[:tracker_ids]
        data[:searchable] = options[:searchable] unless options[:searchable].nil?
        data[:visible] = options[:visible] unless options[:visible].nil?
        data[:default_value] = options[:default_value] if options[:default_value]

        result = client.post("/extended_api/custom_fields", { custom_field: data })
        output_detail(result["custom_field"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update a custom field (requires Extended API plugin)"
      option :name, type: :string
      option :is_required, type: :boolean
      option :is_for_all, type: :boolean
      option :possible_values, type: :string
      option :default_value, type: :string
      def update(id)
        data = {}
        data[:name] = options[:name] if options[:name]
        data[:is_required] = options[:is_required] unless options[:is_required].nil?
        data[:is_for_all] = options[:is_for_all] unless options[:is_for_all].nil?
        data[:possible_values] = options[:possible_values].split(",").map(&:strip) if options[:possible_values]
        data[:default_value] = options[:default_value] if options[:default_value]

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/extended_api/custom_fields/#{id}", { custom_field: data })
        if result.empty?
          result = client.get("/custom_fields")
          cf = (result["custom_fields"] || []).find { |f| f["id"].to_s == id.to_s }
          result = cf || result
        end
        output_detail(result.is_a?(Hash) && result["custom_field"] ? result["custom_field"] : result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a custom field (requires Extended API plugin)"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("delete custom field ##{id}")
        client.delete("/extended_api/custom_fields/#{id}")
        puts "Deleted custom field ##{id}"
      end
    end
  end
end
