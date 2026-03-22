# frozen_string_literal: true

require "faraday"
require "faraday/middleware"
require "json"
require "cgi"

module Rdm
  # HTTP client for Redmine REST API using Faraday.
  # Configured once per session with API key header; connection reused across requests.
  class Client
    USER_AGENT = "rdm/#{Rdm::VERSION}"
    MAX_PAGES = 100

    # Collection keys the Redmine API returns
    COLLECTION_KEYS = %w[
      projects issues users time_entries versions wiki_pages
      issue_statuses trackers custom_fields roles groups
      memberships issue_relations news queries attachments
      issue_priorities time_entry_activities results
    ].freeze

    attr_reader :base_url

    def initialize(base_url:, api_key:, timeout: 30, debug: false)
      @base_url = base_url.chomp("/")
      @api_key = api_key
      @debug = debug
      @auth_failure_count = 0

      @conn = build_connection(timeout)
    end

    # GET request
    def get(path, params = {})
      request(:get, ensure_json_extension(path), params: params)
    end

    # POST request with JSON envelope body
    def post(path, body = {})
      request(:post, ensure_json_extension(path), body: body)
    end

    # PUT request with JSON envelope body
    def put(path, body = {})
      request(:put, ensure_json_extension(path), body: body)
    end

    # DELETE request
    def delete(path)
      request(:delete, ensure_json_extension(path))
    end

    # Paginated GET — yields pages or returns all items
    def paginate(path, params = {}, limit: 100)
      all_items = []
      offset = params.fetch(:offset, 0).to_i
      params = params.merge(limit: [limit, 100].min)
      pages_fetched = 0

      loop do
        raise Error, "Maximum pagination limit reached (#{MAX_PAGES} pages)" if pages_fetched >= MAX_PAGES

        params[:offset] = offset
        response = get(path, params)

        collection_key = detect_collection_key(response)
        items = response[collection_key] || []
        total_count = response["total_count"] || items.size

        if block_given?
          yield items, offset, total_count
        else
          all_items.concat(items)
        end

        pages_fetched += 1
        break if items.size < params[:limit] || offset + items.size >= total_count

        offset += params[:limit]
      end

      block_given? ? nil : all_items
    end

    # Validate connection by fetching current user
    def test_connection
      response = get("/users/current")
      response["user"]
    end

    # Debug mode flag
    def debug?
      @debug || ENV["RDM_DEBUG"] == "1"
    end

    private

    def build_connection(timeout)
      Faraday.new(url: @base_url) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.response :raise_error
        f.headers["X-Redmine-API-Key"] = @api_key
        f.headers["Accept"] = "application/json"
        f.headers["User-Agent"] = USER_AGENT
        f.options.timeout = timeout
        f.options.open_timeout = 10

        if debug?
          f.response :logger, nil, { headers: false, bodies: true } do |logger|
            logger.filter(/(X-Redmine-API-Key:\s*)"[^"]*"/i, '\1"[REDACTED]"')
            logger.filter(/(api_key["\s:=]+)[^\s&"]+/i, '\1[REDACTED]')
            logger.filter(/(password["\s:=]+)[^\s&"]+/i, '\1[REDACTED]')
          end
        end

        f.adapter Faraday.default_adapter
      end
    end

    def request(method, path, params: {}, body: nil)
      check_auth_backoff

      debug_log("#{method.to_s.upcase} #{path}") if debug?

      response = case method
                 when :get
                   @conn.get(path) { |req| req.params = stringify_params(params) if params.any? }
                 when :post
                   @conn.post(path, body)
                 when :put
                   @conn.put(path, body)
                 when :delete
                   @conn.delete(path)
                 end

      @auth_failure_count = 0 # Reset on success
      parse_response(response)
    rescue Faraday::UnauthorizedError => e
      @auth_failure_count += 1
      body = parse_error_body(e.response&.[](:body))
      raise AuthError.new(
        "Authentication failed. Run `rdm login` to re-authenticate.",
        status: 401, response_body: body
      )
    rescue Faraday::ForbiddenError => e
      body = parse_error_body(e.response&.[](:body))
      raise ForbiddenError.new(
        "Permission denied. You don't have access to this resource.",
        status: 403, response_body: body
      )
    rescue Faraday::ResourceNotFound => e
      body = parse_error_body(e.response&.[](:body))
      raise NotFoundError.new(
        "Resource not found",
        status: 404, response_body: body
      )
    rescue Faraday::UnprocessableEntityError => e
      body = parse_error_body(e.response&.[](:body))
      errors = extract_errors(body)
      raise ValidationError.new(
        "Validation failed: #{errors.join(", ")}",
        status: 422, response_body: body, errors: errors
      )
    rescue Faraday::TimeoutError => e
      raise Rdm::TimeoutError, "Request timed out. (#{e.message})"
    rescue Faraday::ServerError => e
      status = e.response&.[](:status) || 500
      raise Rdm::ServerError.new(
        "Redmine server error (HTTP #{status}). Try again later.",
        status: status
      )
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, "Cannot connect to #{@base_url}. Is Redmine running? (#{e.message})"
    end

    def parse_response(response)
      return {} if response.status == 204
      return {} if response.body.nil? || (response.body.is_a?(String) && response.body.strip.empty?)

      if response.body.is_a?(Hash)
        response.body
      elsif response.body.is_a?(String)
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def parse_error_body(body)
      return {} if body.nil?
      return body if body.is_a?(Hash)

      JSON.parse(body)
    rescue JSON::ParserError, TypeError
      {}
    end

    def extract_errors(body)
      return ["Unknown error"] unless body.is_a?(Hash)

      if body["errors"]
        Array(body["errors"])
      elsif body["error"]
        [body["error"]]
      else
        ["Unknown error"]
      end
    end

    def detect_collection_key(response)
      COLLECTION_KEYS.find { |key| response.key?(key) }
    end

    def ensure_json_extension(path)
      return path if path.end_with?(".json")
      return path if path.include?(".json?")

      path.include?("?") ? path.sub("?", ".json?") : "#{path}.json"
    end

    def stringify_params(params)
      params.each_with_object({}) do |(k, v), h|
        h[k.to_s] = v.to_s
      end
    end

    # Exponential backoff on repeated 401 failures
    def check_auth_backoff
      return if @auth_failure_count < 3

      delay = case @auth_failure_count
              when 3..4 then 5
              else 30
              end
      debug_log("Auth backoff: sleeping #{delay}s after #{@auth_failure_count} consecutive 401 failures")
      sleep(delay)
    end

    def debug_log(msg)
      warn "[rdm debug] #{msg}" if debug?
    end
  end
end
