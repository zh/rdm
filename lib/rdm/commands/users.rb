# frozen_string_literal: true

module Rdm
  module Commands
    class Users < Base
      namespace "users"

      LIST_COLUMNS = %w[id login firstname lastname mail admin status created_on].freeze
      DETAIL_FIELDS = %w[id login firstname lastname mail admin status created_on last_login_on groups memberships].freeze

      desc "list", "List users"
      option :status, type: :string, desc: "0=anonymous, 1=active, 2=registered, 3=locked"
      option :name, type: :string, desc: "Filter by name or login"
      option :group_id, type: :numeric
      option :limit, type: :numeric, default: 25
      option :offset, type: :numeric, default: 0
      def list
        params = {}
        params[:status] = options[:status] if options[:status]
        params[:name] = options[:name] if options[:name]
        params[:group_id] = options[:group_id] if options[:group_id]
        params[:limit] = options[:limit]
        params[:offset] = options[:offset]

        result = client.get("/users", params)
        output(result["users"] || [], columns: LIST_COLUMNS)
      end

      desc "show ID", "Show user details (use 'me' for current user)"
      option :include, type: :string, desc: "groups,memberships"
      def show(id)
        path = id == "me" ? "/users/current" : "/users/#{id}"
        params = {}
        params[:include] = options[:include] if options[:include]
        result = client.get(path, params)
        output_detail(result["user"] || result, fields: DETAIL_FIELDS)
      end

      desc "create", "Create a new user"
      option :login, type: :string, required: true
      option :firstname, type: :string, required: true
      option :lastname, type: :string, required: true
      option :mail, type: :string, required: true
      option :password, type: :string
      option :generate_password, type: :boolean
      option :send_information, type: :boolean
      option :admin, type: :boolean
      option :custom_fields, type: :string, desc: "JSON array"
      def create
        data = {
          login: options[:login],
          firstname: options[:firstname],
          lastname: options[:lastname],
          mail: options[:mail]
        }
        data[:password] = options[:password] if options[:password]
        data[:generate_password] = options[:generate_password] unless options[:generate_password].nil?
        data[:must_change_passwd] = true if options[:password]
        data[:send_information] = options[:send_information] unless options[:send_information].nil?
        data[:admin] = options[:admin] unless options[:admin].nil?
        data[:custom_fields] = JSON.parse(options[:custom_fields]) if options[:custom_fields]

        result = client.post("/users", { user: data })
        output_detail(result["user"] || result, fields: DETAIL_FIELDS)
      end

      desc "update ID", "Update a user"
      option :login, type: :string
      option :firstname, type: :string
      option :lastname, type: :string
      option :mail, type: :string
      option :admin, type: :boolean
      option :custom_fields, type: :string, desc: "JSON array"
      def update(id)
        data = {}
        %i[login firstname lastname mail].each do |field|
          data[field] = options[field] if options[field]
        end
        data[:admin] = options[:admin] unless options[:admin].nil?
        data[:custom_fields] = JSON.parse(options[:custom_fields]) if options[:custom_fields]

        if data.empty?
          $stderr.puts "No fields to update."
          exit 4
        end

        result = client.put("/users/#{id}", { user: data })
        if result.empty?
          result = client.get("/users/#{id}")
        end
        output_detail(result["user"] || result, fields: DETAIL_FIELDS)
      end

      desc "delete ID", "Delete a user"
      option :confirm, type: :boolean, default: false
      def delete(id)
        require_confirm!("permanently delete user ##{id}")
        client.delete("/users/#{id}")
        puts "Deleted user ##{id}"
      end
    end
  end
end
