# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Urls
      WATCH = "https://www.youtube.com/watch"
      CHANNEL = "https://www.youtube.com/channel"
      PLAYLIST = "https://www.youtube.com/playlist"

      def self.video(id)
        return nil if id.to_s.empty?

        "#{WATCH}?v=#{id}"
      end

      def self.channel(id)
        return nil if id.to_s.empty?

        "#{CHANNEL}/#{id}"
      end

      def self.playlist(id)
        return nil if id.to_s.empty?

        "#{PLAYLIST}?list=#{id}"
      end

      def self.handle(custom_url)
        handle = custom_url.to_s.strip
        return nil if handle.empty?

        handle = handle.delete_prefix("@")
        "https://www.youtube.com/@#{handle}"
      end
    end
  end
end
