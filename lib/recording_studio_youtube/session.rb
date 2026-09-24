# frozen_string_literal: true

require_relative "gateway"

module RecordingStudio
  module YouTube
    class Session
      def initialize(authorization, configuration: RecordingStudio::YouTube.configuration)
        @gateway = Gateway.new(authorization, configuration: configuration)
      end

      def search(...)
        @gateway.search(...)
      end

      def video(id)
        @gateway.video(id)
      end

      def videos(ids)
        @gateway.videos(ids)
      end

      def channel(...)
        @gateway.channel(...)
      end

      def channel_videos(...)
        @gateway.channel_videos(...)
      end

      def playlist(id)
        @gateway.playlist(id)
      end

      def playlist_items(...)
        @gateway.playlist_items(...)
      end

      def comments(...)
        @gateway.comments(...)
      end

      def comment_replies(...)
        @gateway.comment_replies(...)
      end

      def caption_tracks(...)
        @gateway.caption_tracks(...)
      end

      def download_caption(...)
        @gateway.download_caption(...)
      end
    end
  end
end
