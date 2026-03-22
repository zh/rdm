# frozen_string_literal: true

require "json"

module Rdm
  # Formats output as JSON, table, or CSV.
  # Auto-detects format based on TTY when not explicitly specified.
  class Formatter
    class << self
      def output(data, format:, columns: nil)
        case format.to_sym
        when :json
          render_json(data)
        when :table
          render_table(data, columns)
        when :csv
          render_csv(data, columns)
        else
          render_json(data)
        end
      end

      # Render a single resource as key-value pairs
      def detail(data, fields: nil)
        return render_json(data) unless data.is_a?(Hash)

        fields ||= data.keys
        max_label = fields.map { |f| humanize(f).length }.max || 0

        fields.filter_map do |field|
          value = extract_value(data, field)
          next if value.nil?

          label = humanize(field).ljust(max_label + 1)
          "#{label} #{value}"
        end.join("\n")
      end

      def auto_format
        $stdout.tty? ? :table : :json
      end

      private

      def render_json(data)
        JSON.pretty_generate(data)
      end

      def render_table(data, columns)
        rows = normalize_rows(data)
        return "(no results)" if rows.empty?

        columns ||= rows.first.keys
        columns = columns.map(&:to_s)

        # Compute column widths
        widths = columns.map { |col| col.length }
        rows.each do |row|
          columns.each_with_index do |col, i|
            val = extract_value(row, col).to_s
            widths[i] = [widths[i], val.length].max
          end
        end

        # Cap columns to reasonable width
        widths = widths.map { |w| [w, 60].min }

        lines = []
        # Header
        header = columns.each_with_index.map { |col, i| humanize(col).ljust(widths[i]) }.join("  ")
        lines << header
        lines << widths.map { |w| "-" * w }.join("  ")

        # Rows
        rows.each do |row|
          line = columns.each_with_index.map do |col, i|
            val = extract_value(row, col).to_s
            val = val[0..(widths[i] - 1)] if val.length > widths[i]
            val.ljust(widths[i])
          end.join("  ")
          lines << line
        end

        lines.join("\n")
      end

      def render_csv(data, columns)
        rows = normalize_rows(data)
        return "" if rows.empty?

        columns ||= rows.first.keys
        columns = columns.map(&:to_s)

        lines = [columns.join(",")]
        rows.each do |row|
          line = columns.map do |col|
            val = extract_value(row, col).to_s
            val.include?(",") || val.include?('"') ? "\"#{val.gsub('"', '""')}\"" : val
          end.join(",")
          lines << line
        end

        lines.join("\n")
      end

      def normalize_rows(data)
        case data
        when Array then data
        when Hash
          # If it looks like a paginated response, extract the collection
          key = Rdm::Client::COLLECTION_KEYS.find { |k| data.key?(k) }
          key ? Array(data[key]) : [data]
        else
          []
        end
      end

      # Extract a display value from a row. Handles nested Redmine objects
      # like {"tracker": {"id": 1, "name": "Bug"}} -> "Bug"
      def extract_value(row, field)
        val = row[field] || row[field.to_s] || row[field.to_sym]
        case val
        when Hash
          val["name"] || val["login"] || val["value"] || val["id"]
        when Array
          val.map { |v| v.is_a?(Hash) ? (v["name"] || v["id"]) : v }.join(", ")
        when nil
          nil
        else
          val
        end
      end

      def humanize(field)
        field.to_s.split("_").map(&:capitalize).join(" ")
      end
    end
  end
end
