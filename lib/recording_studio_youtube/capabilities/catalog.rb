# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Capabilities
      TABLE = {
        search: read(
          :search, "search.list",
          "Search uses its own daily bucket of 100 calls. A search item is not a full video."
        ),
        get_video: read(:get_video, "videos.list"),
        get_channel: read(:get_channel, "channels.list"),
        get_mine_channel: read(
          :get_mine_channel, "channels.list",
          "Returns the YouTube channel for the authorized Google account. " \
          "It does not return the Google account itself.",
          authentication: USER, scopes: [Oauth::READONLY]
        ),
        get_channel_videos: read(
          :get_channel_videos, "playlistItems.list",
          "Resolves the channel uploads playlist, then reads playlist items. " \
          "That is one channels.list call plus one playlistItems.list call per page."
        ),
        get_playlist: read(:get_playlist, "playlists.list"),
        get_playlist_items: read(:get_playlist_items, "playlistItems.list"),
        get_comments: read(
          :get_comments, "commentThreads.list",
          "Returns comment threads. Replies included on a thread may be a partial set."
        ),
        get_comment_replies: read(:get_comment_replies, "comments.list"),
        list_caption_tracks: read(
          :list_caption_tracks, "captions.list",
          "Requires user authorization. Does not return caption text. An API key cannot list caption tracks.",
          authentication: USER, scopes: SSL
        ),
        download_caption: read(
          :download_caption, "captions.download",
          "Requires authorization from someone allowed to edit the video. This is not a public transcript API.",
          authentication: USER, scopes: SSL
        ),
        upload_video: write(
          :upload_video, "videos.insert", [Oauth::UPLOAD],
          "Not implemented. Upload uses the video insert bucket, default 100 calls per day."
        ),
        update_video: write(:update_video, "videos.update", [Oauth::FORCE_SSL], "Not implemented."),
        delete_video: write(:delete_video, "videos.delete", [Oauth::FORCE_SSL], "Not implemented."),
        create_playlist: write(:create_playlist, "playlists.insert", [Oauth::FORCE_SSL], "Not implemented."),
        update_playlist: write(:update_playlist, "playlists.update", [Oauth::FORCE_SSL], "Not implemented."),
        add_playlist_item: write(
          :add_playlist_item, "playlistItems.insert", [Oauth::FORCE_SSL], "Not implemented."
        ),
        remove_playlist_item: write(
          :remove_playlist_item, "playlistItems.delete", [Oauth::FORCE_SSL], "Not implemented."
        ),
        subscribe: write(:subscribe, "subscriptions.insert", [Oauth::FORCE_SSL], "Not implemented."),
        unsubscribe: write(:unsubscribe, "subscriptions.delete", [Oauth::FORCE_SSL], "Not implemented."),
        create_comment: write(:create_comment, "commentThreads.insert", [Oauth::FORCE_SSL], "Not implemented."),
        delete_comment: write(:delete_comment, "comments.delete", [Oauth::FORCE_SSL], "Not implemented."),
        manage_captions: write(
          :manage_captions, "captions.insert", SSL,
          "Not implemented. Insert, update, and delete are separate quota costs."
        )
      }.freeze
    end
  end
end
