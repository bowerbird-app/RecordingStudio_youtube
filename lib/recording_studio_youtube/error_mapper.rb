# frozen_string_literal: true

require "json"
require_relative "errors"

module RecordingStudio
  module YouTube
    class ErrorMapper
      REASON_CLASSES = {
        "quotaExceeded" => QuotaExceededError,
        "dailyLimitExceeded" => QuotaExceededError,
        "rateLimitExceeded" => RateLimitError,
        "userRateLimitExceeded" => RateLimitError,
        "authError" => AuthenticationError,
        "invalidCredentials" => AuthenticationError,
        "keyInvalid" => AuthenticationError,
        "forbidden" => AuthorizationError,
        "insufficientPermissions" => AuthorizationError,
        "accountClosed" => AuthorizationError,
        "ipRefererBlocked" => AuthorizationError,
        "commentsDisabled" => AuthorizationError,
        "channelForbidden" => AuthorizationError
      }.freeze
      STATUS_CLASSES = {
        429 => RateLimitError,
        401 => AuthenticationError,
        403 => AuthorizationError,
        404 => NotFoundError,
        400 => InvalidRequestError
      }.freeze

      def self.raise_http(status, body, operation:, secrets:)
        parsed = parse_json(body)
        error = parsed.is_a?(Hash) ? parsed["error"] : nil
        reason = reason_from(error)
        domain = domain_from(error)
        message = redact(message_from(error, body), secrets)
        details = details_from(error, secrets)
        klass = class_for(status, reason)
        raise klass.new(message, status: status, reason: reason, domain: domain, operation: operation, details: details)
      end

      def self.raise_empty(operation, resource)
        raise NotFoundError.new(
          "#{resource} was not found",
          status: 404,
          reason: "notFound",
          operation: operation
        )
      end

      def self.parse_json(body)
        return {} if body.nil? || body.to_s.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def self.class_for(status, reason)
        REASON_CLASSES[reason] || STATUS_CLASSES[status] || ApiError
      end

      def self.reason_from(error)
        return nil unless error.is_a?(Hash)

        first = Array(error["errors"]).first
        return first["reason"] if first.is_a?(Hash) && first["reason"]

        error["status"]
      end

      def self.domain_from(error)
        return nil unless error.is_a?(Hash)

        first = Array(error["errors"]).first
        first["domain"] if first.is_a?(Hash)
      end

      def self.message_from(error, body)
        return error["message"] if error.is_a?(Hash) && error["message"]
        return "YouTube returned an empty error response" if body.to_s.strip.empty?

        "YouTube request failed"
      end

      def self.details_from(error, secrets)
        return nil unless error.is_a?(Hash)

        Array(error["errors"]).filter_map do |item|
          next unless item.is_a?(Hash)

          {
            "reason" => item["reason"],
            "domain" => item["domain"],
            "message" => redact(item["message"], secrets)
          }
        end
      end

      def self.redact(text, secrets)
        Array(secrets).compact.reduce(text.to_s) do |memo, secret|
          next memo if secret.to_s.empty?

          memo.gsub(secret.to_s, "[redacted]")
        end
      end

      private_class_method :class_for, :reason_from, :domain_from,
                           :message_from, :details_from, :redact
    end
  end
end
