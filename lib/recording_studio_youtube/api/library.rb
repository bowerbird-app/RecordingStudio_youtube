# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      module Library
        DEFINITIONS = [
          {
            name: :"youtube.get_channel_videos", http_verb: :get, path: "youtube/channel_videos",
            handler: ChannelVideos,
            openapi: Endpoints.openapi(
              "Read a channel's uploads",
              "Reads one page from a channel uploads playlist. Not a search.",
              [
                Endpoints.query(:channel_id, "YouTube channel id. Required unless uploads_playlist_id is set."),
                Endpoints.query(:uploads_playlist_id, "Uploads playlist id from an earlier page."),
                Endpoints.query(:max_results, "Page size from 0 to 50. The default is 5.", type: "integer"),
                Endpoints.query(:page_token, "Token from a previous page.")
              ]
            ),
            input_contract: Fields.query_contract(
              channel_id: Fields.string("YouTube channel id. Required unless uploads_playlist_id is set."),
              uploads_playlist_id: Fields.string("Uploads playlist id from an earlier page."),
              max_results: Fields.max_results(default: 5, max: 50),
              page_token: Fields.page_token
            )
          },
          {
            name: :"youtube.get_playlist", http_verb: :get, path: "youtube/playlists/:id", handler: Playlist,
            openapi: Endpoints.openapi(
              "Read a YouTube playlist",
              "Reads public metadata for one playlist id.",
              [Endpoints.query(:id, "YouTube playlist id.", required: true, location: "path")]
            ),
            input_contract: Fields.query_contract(id: Fields.id("YouTube playlist"))
          },
          {
            name: :"youtube.get_playlist_items", http_verb: :get, path: "youtube/playlists/:id/items",
            handler: PlaylistItems,
            openapi: Endpoints.openapi(
              "Read playlist items",
              "Reads one page of videos in a public playlist.",
              [
                Endpoints.query(:id, "YouTube playlist id.", required: true, location: "path"),
                Endpoints.query(:max_results, "Page size from 0 to 50. The default is 5.", type: "integer"),
                Endpoints.query(:page_token, "Token from a previous page.")
              ]
            ),
            input_contract: Fields.query_contract(
              id: Fields.id("YouTube playlist"),
              max_results: Fields.max_results(default: 5, max: 50),
              page_token: Fields.page_token
            )
          },
          {
            name: :"youtube.get_comments", http_verb: :get, path: "youtube/comments", handler: Comments,
            openapi: Endpoints.openapi(
              "Read video comments",
              "Reads public comment threads on a video. A thread may include only some replies.",
              [
                Endpoints.query(:video_id, "YouTube video id.", required: true),
                Endpoints.query(:max_results, "Page size from 1 to 100. The default is 20.", type: "integer"),
                Endpoints.query(:page_token, "Token from a previous page."),
                Endpoints.query(:order, "time or relevance."),
                Endpoints.query(:search_terms, "Limit comments to text that contains these words.")
              ]
            ),
            input_contract: Fields.query_contract(
              video_id: Fields.id("YouTube video"),
              max_results: Fields.comment_max_results,
              page_token: Fields.page_token,
              order: Fields.string("time or relevance."),
              search_terms: Fields.string("Limit comments to text that contains these words.")
            )
          },
          {
            name: :"youtube.get_comment_replies", http_verb: :get, path: "youtube/comment_replies",
            handler: CommentReplies,
            openapi: Endpoints.openapi(
              "Read comment replies",
              "Reads replies for one parent comment.",
              [
                Endpoints.query(:parent_id, "Parent comment id.", required: true),
                Endpoints.query(:max_results, "Page size from 1 to 100. The default is 20.", type: "integer"),
                Endpoints.query(:page_token, "Token from a previous page.")
              ]
            ),
            input_contract: Fields.query_contract(
              parent_id: Fields.id("Parent comment"),
              max_results: Fields.comment_max_results,
              page_token: Fields.page_token
            )
          }
        ].freeze
      end
    end
  end
end
