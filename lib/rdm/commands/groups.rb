# frozen_string_literal: true

module Rdm
  module Commands
    class Groups < Base
      namespace "groups"

      LIST_COLUMNS = %w[id name].freeze
      DETAIL_FIELDS = %w[id name users memberships].freeze

      desc "list", "List groups"
      def list
        result = client.get("/groups")
        output(result["groups"] || [], columns: LIST_COLUMNS)
      end

      desc "show ID", "Show group details"
      option :include, type: :string, desc: "users,memberships"
      def show(id)
        params = {}
        params[:include] = options[:include] if options[:include]
        result = client.get("/groups/#{id}", params)
        output_detail(result["group"] || result, fields: DETAIL_FIELDS)
      end

      desc "create", "Create a group"
      option :name, type: :string, required: true
      option :user_ids, type: :string, desc: "Comma-separated user IDs"
      def create
        data = { name: options[:name] }
        data[:user_ids] = options[:user_ids].split(",").map { |id| id.strip.to_i } if options[:user_ids]

        result = client.post("/groups", { group: data })
        output_detail(result["group"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update a group"
      option :name, type: :string
      option :user_ids, type: :string, desc: "Comma-separated user IDs (replaces all)"
      def update(id)
        data = {}
        data[:name] = options[:name] if options[:name]
        data[:user_ids] = options[:user_ids].split(",").map { |id| id.strip.to_i } if options[:user_ids]

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/groups/#{id}", { group: data })
        if result.empty?
          result = client.get("/groups/#{id}")
        end
        output_detail(result["group"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a group"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("delete group ##{id}")
        client.delete("/groups/#{id}")
        puts "Deleted group ##{id}"
      end
    end
  end
end
