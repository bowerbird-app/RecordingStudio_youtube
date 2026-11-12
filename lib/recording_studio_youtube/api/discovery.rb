# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      module Discovery
        SEARCH_FIELDS = {
          query: Fields.string("Words to search for. Required unless channel_id is set."),
          type: Fields.string("Limit results to video, channel, or playlist."),
          channel_id: Fields.string("Only resources from this channel id."),
          order: Fields.string("date, rating, relevance, title, videoCount, or viewCount."),
          published_after: Fields.string("RFC 3339 timestamp. Include resources published at or after this time."),
          published_before: Fields.string("RFC 3339 timestamp. Include resources published before this time."),
          language: Fields.string("ISO 639-1 language code used for relevance, such as en."),
          region: Fields.string("ISO 3166-1 alpha-2 region code, such as US."),
          video_duration: Fields.string("any, short, medium, or long. Applies to video results."),
          safe_search: Fields.string("moderate, none, or strict."),
          max_results: Fields.max_results(default: 5, max: 50),
          page_token: Fields.page_token
        }.freeze

        DEFINITIONS = [
          {
            name: :"youtube.search", http_verb: :get, path: "youtube/search", handler: Search,
            openapi: Endpoints.openapi(
              "Search public YouTube",
              "Searches public videos, channels, or playlists. This spends the host YouTube Data API quota " \
              "on the existing search.list bucket (100 calls a day). Results are light search items, not " \
              "full videos.",
              SEARCH_FIELDS.map { |name, rules| Endpoints.query(name, rules[:description], type: rules[:type].to_s) }
            ),
            input_contract: Fields.query_contract(SEARCH_FIELDS)
          },
          {
            name: :"youtube.get_video", http_verb: :get, path: "youtube/videos/:id", handler: Video,
            openapi: Endpoints.openapi(
              "Read a YouTube video",
              "Reads public metadata for one video id.",
              [Endpoints.query(:id, "YouTube video id.", required: true, location: "path")]
            ),
            input_contract: Fields.query_contract(id: Fields.id("YouTube video"))
          },
          {
            name: :"youtube.get_videos", http_verb: :get, path: "youtube/videos", handler: Videos,
            openapi: Endpoints.openapi(
              "Read YouTube videos",
              "Reads public metadata for up to 50 video ids in one videos.list call.",
              [Endpoints.query(:ids, "Video ids. Repeat the param or send a comma-separated list.", type: "array")]
            ),
            input_contract: Fields.query_contract(
              ids: {
                type: :array, required: false,
                description: "Video ids. Repeat the param or send a comma-separated list."
              },
              id: Fields.string("One video id. Use ids for more than one.")
            )
          },
          {
            name: :"youtube.get_channel", http_verb: :get, path: "youtube/channels", handler: Channel,
            openapi: Endpoints.openapi(
              "Read a YouTube channel",
              "Reads a public channel by id or handle. Specify exactly one.",
              [
                Endpoints.query(:id, "YouTube channel id."),
                Endpoints.query(:handle, "YouTube handle, with or without @.")
              ]
            ),
            input_contract: Fields.query_contract(
              id: Fields.string("YouTube channel id."),
              handle: Fields.string("YouTube handle, with or without @.")
            )
          }
        ].freeze
      end
    end
  end
end
