# frozen_string_literal: true

module RecordingStudio
  module YouTube
    class Authorization
      def self.resolve(connection: nil, access_token: nil, configuration: RecordingStudio::YouTube.configuration)
        token = access_token || token_from(connection)
        return Bearer.new(token) if token

        key = configuration.api_key
        raise ConfigurationError, "YouTube Data API key is not configured" if key.to_s.strip.empty?

        ApiKey.new(key)
      end

      def self.from_connection(connection)
        token = access_token_from(connection)
        raise ConfigurationError, "connection has no access token" if token.to_s.strip.empty?

        Bearer.new(token)
      end

      def self.access_token_from(connection)
        token_from(connection)
      end

      def self.token_from(connection)
        stripped = token_value(connection).to_s.strip
        stripped.empty? ? nil : stripped
      end

      def self.token_value(connection)
        return nil if connection.nil? || connection.is_a?(String)

        from_method = connection.access_token if connection.respond_to?(:access_token)
        return from_method unless from_method.nil?
        return nil unless connection.respond_to?(:[])

        connection[:access_token] || connection["access_token"]
      end
      private_class_method :token_from, :token_value

      class ApiKey
        attr_reader :key

        def initialize(key)
          @key = key
        end

        def type
          :api_key
        end

        def apply(params, headers)
          params["key"] = key
          headers
        end
      end

      class Bearer
        attr_reader :token

        def initialize(token)
          @token = token
        end

        def type
          :user
        end

        def apply(_params, headers)
          headers["Authorization"] = "Bearer #{token}"
          headers
        end
      end
    end
  end
end
