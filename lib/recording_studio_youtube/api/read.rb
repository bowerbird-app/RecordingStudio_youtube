# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      class Read
        def self.call(context)
          context.access_grant.authorize!(recording: context.root_recording, role: VIEW_ROLE)
          payload_for(context.params)
        rescue RecordingStudio::YouTube::Error => e
          Errors.raise_mapped!(e)
        end

        def self.payload_for(params)
          RecordingStudio::YouTube::AiTools.execute(self::TOOL, stringify(params))
        end

        def self.stringify(params)
          params.to_h.transform_keys(&:to_s)
        end
        private_class_method :stringify
      end

      class Video < Read
        TOOL = "youtube_get_video"
      end

      class Channel < Read
        TOOL = "youtube_get_channel"
      end

      class ChannelVideos < Read
        TOOL = "youtube_get_channel_videos"
      end

      class Playlist < Read
        TOOL = "youtube_get_playlist"
      end

      class PlaylistItems < Read
        TOOL = "youtube_get_playlist_items"
      end

      class Comments < Read
        TOOL = "youtube_get_comments"
      end

      class Videos < Read
        def self.payload_for(params)
          ids = Array(params[:ids] || params[:id]).flat_map { |value| value.to_s.split(",") }
          { "items" => RecordingStudio::YouTube.videos(ids).map(&:to_agent) }
        end
      end

      class CommentReplies < Read
        TOOL = "youtube_get_comment_replies"
      end
    end
  end
end
