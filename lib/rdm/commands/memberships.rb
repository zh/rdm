# frozen_string_literal: true

module Rdm
  module Commands
    class Memberships < Base
      namespace "memberships"

      LIST_COLUMNS = %w[id project user roles].freeze
      DETAIL_FIELDS = %w[id project user group roles].freeze

      desc "list", "List project memberships"
      option :project_id, type: :string, required: true
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def list
        params = { limit: options[:limit], offset: options[:offset] }
        result = client.get("/projects/#{options[:project_id]}/memberships", params)
        output(result["memberships"] || [], columns: LIST_COLUMNS)
      end

      desc "show ID", "Show membership details"
      def show(id)
        result = client.get("/memberships/#{id}")
        output_detail(result["membership"] || result, fields: DETAIL_FIELDS)
      end

      desc "create", "Add a member to a project"
      option :project_id, type: :string, required: true
      option :user_id, type: :numeric, required: true
      option :role_ids, type: :string, required: true, desc: "Comma-separated role IDs"
      def create
        data = {
          user_id: options[:user_id],
          role_ids: options[:role_ids].split(",").map { |id| id.strip.to_i }
        }
        result = client.post("/projects/#{options[:project_id]}/memberships", { membership: data })
        output_detail(result["membership"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Remove a membership"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("delete membership ##{id}")
        client.delete("/memberships/#{id}")
        puts "Deleted membership ##{id}"
      end
    end
  end
end
