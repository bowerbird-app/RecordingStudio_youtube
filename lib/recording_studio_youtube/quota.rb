# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Quota
      SOURCE = "https://developers.google.com/youtube/v3/determine_quota_cost"
      UPDATED_ON = "2026-09-15"
      STANDARD_DAILY_LIMIT = 10_000

      Entry = Data.define(:operation, :units, :bucket, :daily_limit, :note)

      def self.fetch(operation)
        TABLE.fetch(operation.to_s) do
          raise Error, "unknown YouTube quota operation: #{operation}"
        end
      end

      def self.table
        TABLE.values
      end

      TABLE = {
        "search.list" => Entry.new(
          "search.list",
          1,
          "search_queries",
          100,
          "Separate Search Queries bucket. Each call costs 1. The default daily limit is 100 calls."
        ),
        "videos.list" => Entry.new("videos.list", 1, "standard", STANDARD_DAILY_LIMIT, nil),
        "channels.list" => Entry.new("channels.list", 1, "standard", STANDARD_DAILY_LIMIT, nil),
        "playlists.list" => Entry.new("playlists.list", 1, "standard", STANDARD_DAILY_LIMIT, nil),
        "playlistItems.list" => Entry.new("playlistItems.list", 1, "standard", STANDARD_DAILY_LIMIT, nil),
        "commentThreads.list" => Entry.new("commentThreads.list", 1, "standard", STANDARD_DAILY_LIMIT, nil),
        "comments.list" => Entry.new("comments.list", 1, "standard", STANDARD_DAILY_LIMIT, nil),
        "captions.list" => Entry.new(
          "captions.list",
          50,
          "standard",
          STANDARD_DAILY_LIMIT,
          "Requires user authorization. The response lists tracks and does not include caption text."
        ),
        "captions.download" => Entry.new(
          "captions.download",
          nil,
          "standard",
          nil,
          "Requires authorization from someone allowed to edit the video. " \
          "The quota calculator dated #{UPDATED_ON} does not list a unit cost."
        ),
        "videos.insert" => Entry.new(
          "videos.insert",
          1,
          "video_inserts",
          100,
          "Separate video upload bucket. Each call costs 1. The default daily limit is 100 calls. Not implemented."
        ),
        "videos.update" => Entry.new("videos.update", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "videos.delete" => Entry.new("videos.delete", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "playlists.insert" => Entry.new("playlists.insert", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "playlists.update" => Entry.new("playlists.update", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "playlists.delete" => Entry.new("playlists.delete", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "playlistItems.insert" => Entry.new(
          "playlistItems.insert", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."
        ),
        "playlistItems.delete" => Entry.new(
          "playlistItems.delete", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."
        ),
        "subscriptions.insert" => Entry.new(
          "subscriptions.insert", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."
        ),
        "subscriptions.delete" => Entry.new(
          "subscriptions.delete", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."
        ),
        "commentThreads.insert" => Entry.new(
          "commentThreads.insert", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."
        ),
        "comments.insert" => Entry.new("comments.insert", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "comments.delete" => Entry.new("comments.delete", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "captions.insert" => Entry.new("captions.insert", 400, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "captions.update" => Entry.new("captions.update", 450, "standard", STANDARD_DAILY_LIMIT, "Not implemented."),
        "captions.delete" => Entry.new("captions.delete", 50, "standard", STANDARD_DAILY_LIMIT, "Not implemented.")
      }.freeze
    end
  end
end
