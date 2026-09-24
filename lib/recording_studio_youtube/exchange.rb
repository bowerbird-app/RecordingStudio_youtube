# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "quota"

module RecordingStudio
  module YouTube
    class Exchange
      def initialize(authorization, configuration)
        @authorization = authorization
        @configuration = configuration
      end

      def call(path, params)
        uri = build_uri(path, params)
        transport = @configuration.transport
        return transport.perform(uri, request_headers, timeouts) if transport

        response = http_client(uri).request(Net::HTTP::Get.new(uri, request_headers))
        [response.code.to_i, response.body.to_s, { "content-type" => response["content-type"] }]
      end

      private

      def build_uri(path, params)
        base = URI(@configuration.base_url)
        query = stringify(params)
        headers = {}
        @authorization.apply(query, headers)
        @request_headers = headers
        uri = base.dup
        uri.path = File.join(base.path, path.to_s)
        uri.query = URI.encode_www_form(query)
        uri
      end

      def request_headers
        {
          "Accept" => "application/json",
          "User-Agent" => @configuration.user_agent
        }.merge(@request_headers || {})
      end

      def timeouts
        {
          open: @configuration.open_timeout,
          read: @configuration.read_timeout,
          write: @configuration.write_timeout
        }
      end

      def stringify(params)
        params.each_with_object({}) do |(key, value), memo|
          next if value.nil?

          memo[key.to_s] = value.is_a?(Array) ? value.join(",") : value.to_s
        end
      end

      def http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeouts[:open]
        http.read_timeout = timeouts[:read]
        http.write_timeout = timeouts[:write]
        http
      end
    end

    class RequestEvent
      def self.payload(authorization, path, operation, trace, now)
        quota = Quota.fetch(operation)
        {
          operation: operation,
          endpoint: path.to_s,
          authentication_type: authorization.type,
          request_count: trace[:attempts],
          duration_ms: ((now - trace[:started]) * 1000).round,
          result_count: count(trace[:result]),
          status: trace[:status],
          quota_units: quota.units,
          quota_bucket: quota.bucket,
          error: trace[:error]&.class&.name
        }
      end

      def self.count(result)
        return nil unless result.is_a?(Hash)

        items = result["items"]
        return items.length if items.is_a?(Array)
        return 1 if result.key?("body")

        nil
      end
      private_class_method :count
    end
  end
end
