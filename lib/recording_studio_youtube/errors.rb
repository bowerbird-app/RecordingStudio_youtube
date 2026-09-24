# frozen_string_literal: true

module RecordingStudio
  module YouTube
    class Error < StandardError
      attr_reader :status, :reason, :domain, :operation, :details

      def initialize(message = nil, status: nil, reason: nil, domain: nil, operation: nil, details: nil)
        @status = status
        @reason = reason
        @domain = domain
        @operation = operation
        @details = details
        super(message)
      end
    end

    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class AuthorizationError < Error; end
    class QuotaExceededError < Error; end
    class RateLimitError < Error; end
    class NotFoundError < Error; end
    class InvalidRequestError < Error; end
    class ApiError < Error; end
    class NetworkError < Error; end
    class TimeoutError < NetworkError; end
  end
end
