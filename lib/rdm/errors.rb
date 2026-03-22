# frozen_string_literal: true

module Rdm
  # Base error for all rdm errors
  class Error < StandardError; end

  # Configuration errors (missing config, bad permissions, bad YAML)
  class ConfigError < Error; end

  # Base class for API errors with status code and response body
  class APIError < Error
    attr_reader :status, :response_body, :errors

    def initialize(message, status: nil, response_body: nil, errors: [])
      super(message)
      @status = status
      @response_body = response_body
      @errors = errors
    end
  end

  # 401 Unauthorized
  class AuthError < APIError; end

  # 403 Forbidden
  class ForbiddenError < APIError; end

  # 404 Not Found
  class NotFoundError < APIError; end

  # 422 Unprocessable Entity
  class ValidationError < APIError; end

  # 5xx Server Error
  class ServerError < APIError; end

  # Connection refused / DNS failure
  class ConnectionError < Error; end

  # Request timeout
  class TimeoutError < Error; end

  # Maps HTTP status codes to error classes
  STATUS_ERROR_MAP = {
    401 => AuthError,
    403 => ForbiddenError,
    404 => NotFoundError,
    422 => ValidationError
  }.freeze

  # Maps error classes to exit codes
  EXIT_CODES = {
    AuthError => 2,
    ForbiddenError => 2,
    NotFoundError => 3,
    ValidationError => 4
  }.freeze

  def self.exit_code_for(error)
    EXIT_CODES.fetch(error.class, 1)
  end
end
