# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"
require "active_support/notifications"
require_relative "error_mapper"
require_relative "quota"
require_relative "exchange"

module RecordingStudio
  module YouTube
    class Client
      EVENT_NAME = "request.recording_studio_youtube"
      RETRY_STATUSES = [500, 503].freeze

      def initialize(authorization, configuration: RecordingStudio::YouTube.configuration)
        @authorization = authorization
        @configuration = configuration
      end

      def get(path, params, operation:)
        request(path, params, operation: operation, json: true)
      end

      def get_text(path, params, operation:)
        request(path, params, operation: operation, json: false)
      end

      private

      def request(path, params, operation:, json:)
        trace = { attempts: 0, started: monotonic, status: nil, result: nil, error: nil }
        trace[:result] = dispatch(path, params, operation, json, trace)
        trace[:result]
      ensure
        notify(path, operation, trace) if trace
      end

      def dispatch(path, params, operation, json, trace)
        attempt(path, params, operation, json, trace)
      rescue Error => e
        trace[:error] = e
        raise
      rescue StandardError => e
        raise translated_transport_error(e, operation, trace)
      end

      def translated_transport_error(error, operation, trace)
        return raise error unless transport_failure?(error)

        trace[:error] = transport_error(error, operation)
        raise trace[:error]
      end

      def transport_failure?(error)
        error.is_a?(Timeout::Error) || network_error?(error)
      end

      def network_error?(error)
        error.is_a?(SocketError) || error.is_a?(SystemCallError) ||
          error.is_a?(EOFError) || error.is_a?(OpenSSL::SSL::SSLError)
      end

      def transport_error(error, operation)
        return TimeoutError.new("YouTube request timed out", operation: operation) if error.is_a?(Timeout::Error)

        NetworkError.new("YouTube request failed", operation: operation)
      end

      def attempt(path, params, operation, json, trace)
        loop do
          trace[:attempts] += 1
          status, body, headers = perform(path, params)
          trace[:status] = status
          if retry?(status, trace[:attempts])
            Kernel.sleep(@configuration.retry_wait.to_f)
            next
          end

          return finish(status, body, headers, operation, json)
        end
      end

      def retry?(status, attempts)
        RETRY_STATUSES.include?(status) && attempts <= @configuration.retries
      end

      def finish(status, body, headers, operation, json)
        ErrorMapper.raise_http(status, body, operation: operation, secrets: secrets) if status >= 400
        return { "body" => body.to_s, "content_type" => headers["content-type"] } unless json

        parsed = ErrorMapper.parse_json(body)
        raise ApiError.new("YouTube returned invalid JSON", status: status, operation: operation) if parsed.nil?
        raise ApiError.new("YouTube returned an unexpected response", status: status, operation: operation) unless
          parsed.is_a?(Hash)

        parsed
      end

      def perform(path, params)
        Exchange.new(@authorization, @configuration).call(path, params)
      end

      def secrets
        [secret_from(:key), secret_from(:token)].compact
      end

      def secret_from(name)
        @authorization.public_send(name) if @authorization.respond_to?(name)
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def notify(path, operation, trace)
        return unless @configuration.instrumentation_enabled?

        ActiveSupport::Notifications.instrument(
          EVENT_NAME,
          RequestEvent.payload(@authorization, path, operation, trace, monotonic)
        )
      end
    end
  end
end
