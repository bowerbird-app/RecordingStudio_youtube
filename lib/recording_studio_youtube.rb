# frozen_string_literal: true

require "recording_studio"
require "recording_studio_youtube/version"
require "recording_studio_youtube/errors"
require "recording_studio_youtube/configuration"
require "recording_studio_youtube/quota"
require "recording_studio_youtube/oauth"
require "recording_studio_youtube/capabilities"
require "recording_studio_youtube/authorization"
require "recording_studio_youtube/urls"
require "recording_studio_youtube/values"
require "recording_studio_youtube/error_mapper"
require "recording_studio_youtube/client"
require "recording_studio_youtube/gateway"
require "recording_studio_youtube/session"
require "recording_studio_youtube/ai_tools"
require "recording_studio_youtube/diagnostics"
require "recording_studio_youtube/engine"
require "recording_studio_youtube/capabilities/example"

module RecordingStudio
  module YouTube
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration) if block_given?
      end

      def search(**options)
        gateway_for(options).search(**without_auth(options))
      end

      def video(id, **options)
        gateway_for(options).video(id)
      end

      def videos(ids, **options)
        gateway_for(options).videos(ids)
      end

      def channel(id = nil, **options)
        gateway_for(options).channel(id, **without_auth(options))
      end

      def channel_videos(**options)
        gateway_for(options).channel_videos(**without_auth(options))
      end

      def playlist(id, **options)
        gateway_for(options).playlist(id)
      end

      def playlist_items(id, **options)
        gateway_for(options).playlist_items(id, **without_auth(options))
      end

      def comments(**options)
        gateway_for(options).comments(**without_auth(options))
      end

      def comment_replies(**options)
        gateway_for(options).comment_replies(**without_auth(options))
      end

      def caption_tracks(**options)
        gateway_for(options).caption_tracks(**without_auth(options))
      end

      def download_caption(id, **options)
        gateway_for(options).download_caption(id, **without_auth(options))
      end

      def for(connection)
        Session.new(Authorization.from_connection(connection))
      end

      def capability(key)
        Capabilities.fetch(key)
      end

      def capabilities
        Capabilities.all
      end

      def diagnostics(probe: false)
        Diagnostics.call(probe: probe)
      end

      private

      def gateway_for(options)
        Gateway.new(authorization_for(options))
      end

      def authorization_for(options)
        if options.key?(:access_token) || options.key?(:connection)
          token = options[:access_token]
          token = Authorization.access_token_from(options[:connection]) if token.nil?
          raise ConfigurationError, "connection has no access token" if token.to_s.strip.empty?

          Authorization::Bearer.new(token)
        else
          Authorization.resolve
        end
      end

      def without_auth(options)
        options.except(:connection, :access_token)
      end
    end
  end
end
