# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      module Discovery
        DEFINITIONS = [
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
