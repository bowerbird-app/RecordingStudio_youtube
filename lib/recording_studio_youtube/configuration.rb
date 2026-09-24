# frozen_string_literal: true

module RecordingStudio
  module YouTube
    class Configuration
      DEFAULT_TIMEOUT = 5
      DEFAULT_BASE_URL = "https://www.googleapis.com/youtube/v3"

      attr_accessor :api_key, :oauth_client_id, :timeout,
                    :instrumentation_enabled, :retries, :retry_wait,
                    :transport, :base_url, :user_agent
      attr_writer :open_timeout, :read_timeout, :write_timeout
      attr_reader :hooks

      def initialize
        assign_credentials
        assign_timeouts
        assign_client_defaults
      end

      def open_timeout
        @open_timeout || timeout
      end

      def read_timeout
        @read_timeout || timeout
      end

      def write_timeout
        @write_timeout || timeout
      end

      def api_key_configured?
        present?(@api_key)
      end

      def oauth_client_id_configured?
        present?(@oauth_client_id)
      end

      def instrumentation_enabled?
        @instrumentation_enabled != false
      end

      def to_h
        {
          api_key_configured: api_key_configured?,
          oauth_client_id_configured: oauth_client_id_configured?,
          timeout: timeout,
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          write_timeout: write_timeout,
          instrumentation_enabled: instrumentation_enabled?,
          retries: retries,
          base_url: base_url,
          hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
        }
      end

      def inspect
        "#<#{self.class.name} #{to_h.inspect}>"
      end

      def merge!(hash)
        return unless hash.respond_to?(:each)

        hash.each do |key, value|
          setter = "#{key}="
          public_send(setter, value) if respond_to?(setter)
        end
      end

      private

      def assign_credentials
        @api_key = env_value("youtube_api_key") || env_value("youtube")
        @oauth_client_id = env_value("youtube_client_id")
      end

      def assign_timeouts
        @timeout = DEFAULT_TIMEOUT
        @open_timeout = nil
        @read_timeout = nil
        @write_timeout = nil
      end

      def assign_client_defaults
        @instrumentation_enabled = true
        @retries = 0
        @retry_wait = 0.2
        @transport = nil
        @base_url = DEFAULT_BASE_URL
        @user_agent = "RecordingStudio-YouTube/#{VERSION}"
        @hooks = RecordingStudio::Hooks.new
      end

      def env_value(name)
        value = ENV.fetch(name, nil)
        return nil if value.nil?

        stripped = value.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def present?(value)
        !value.to_s.strip.empty?
      end
    end
  end
end
