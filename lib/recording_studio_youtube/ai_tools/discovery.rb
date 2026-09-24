# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module AiTools
      DISCOVERY = [
        tool(
          key: :youtube_search,
          name: "YouTube search",
          description: "Searches public YouTube videos, channels, or playlists.",
          use_when: "You need to find public YouTube resources and you do not already have their ids.",
          do_not_use_when: "You already have a video, channel, or playlist id. " \
                           "Search has a separate daily limit of 100 calls.",
          parameters: [
            param(:query, :string, false, "Words to search for. Required unless channel_id is set."),
            param(:type, :string, false, "Limit results to video, channel, or playlist."),
            param(:channel_id, :string, false, "Only resources from this channel id."),
            param(:order, :string, false, "date, rating, relevance, title, videoCount, or viewCount."),
            param(:published_after, :string, false,
                  "RFC 3339 timestamp. Include resources published at or after this time."),
            param(:published_before, :string, false,
                  "RFC 3339 timestamp. Include resources published before this time."),
            param(:language, :string, false, "ISO 639-1 language code used for relevance, such as en."),
            param(:region, :string, false, "ISO 3166-1 alpha-2 region code, such as US."),
            param(:video_duration, :string, false, "any, short, medium, or long. Applies to video results."),
            param(:safe_search, :string, false, "moderate, none, or strict."),
            param(:max_results, :integer, false, "Page size from 0 to 50. The default is 5."),
            param(:page_token, :string, false, "Token from a previous page. Omit it for the first page.")
          ],
          returns: "A page of lightweight search items, page tokens, and quota metadata. Items are not full videos.",
          cost: :high,
          executor_label: "RecordingStudio::YouTube.search"
        ),
        tool(
          key: :youtube_get_video,
          name: "YouTube video",
          description: "Reads public metadata for one YouTube video.",
          use_when: "You have a video id and need its title, description, duration, thumbnails, or statistics.",
          do_not_use_when: "You still need to discover the video id.",
          parameters: [param(:id, :string, true, "YouTube video id.")],
          returns: "Video id, title, description, channel, publication time, URL, thumbnail, duration, tags, " \
                   "and statistics.",
          cost: :low,
          executor_label: "RecordingStudio::YouTube.video"
        ),
        tool(
          key: :youtube_get_channel,
          name: "YouTube channel",
          description: "Reads a public YouTube channel by id or handle.",
          use_when: "You have a channel id or a @handle.",
          do_not_use_when: "You only have a display name. Display names are not stable ids.",
          parameters: [
            param(:id, :string, false, "YouTube channel id."),
            param(:handle, :string, false, "YouTube handle, with or without @.")
          ],
          returns: "Channel id, title, description, handle, uploads playlist id, thumbnail, and statistics.",
          cost: :low,
          executor_label: "RecordingStudio::YouTube.channel"
        ),
        tool(
          key: :youtube_get_channel_videos,
          name: "YouTube channel videos",
          description: "Reads videos from a channel's uploads playlist.",
          use_when: "You want videos that belong to a known channel.",
          do_not_use_when: "You are searching by keywords. This uses the uploads playlist, not search.",
          parameters: [
            param(:channel_id, :string, true, "YouTube channel id."),
            param(:max_results, :integer, false, "Page size from 0 to 50. The default is 5."),
            param(:page_token, :string, false, "Token from a previous page.")
          ],
          returns: "A page of uploaded videos plus the uploads playlist id. Each page costs two quota units.",
          cost: :low,
          executor_label: "RecordingStudio::YouTube.channel_videos"
        )
      ].freeze
    end
  end
end
