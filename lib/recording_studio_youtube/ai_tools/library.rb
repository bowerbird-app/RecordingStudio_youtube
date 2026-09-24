# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module AiTools
      LIBRARY = [
        tool(
          key: :youtube_get_playlist,
          name: "YouTube playlist",
          description: "Reads public metadata for one playlist.",
          use_when: "You have a playlist id.",
          do_not_use_when: "You need the videos inside the playlist. Use youtube_get_playlist_items for those.",
          parameters: [param(:id, :string, true, "YouTube playlist id.")],
          returns: "Playlist id, title, description, channel, item count, URL, and thumbnail.",
          cost: :low,
          executor_label: "RecordingStudio::YouTube.playlist"
        ),
        tool(
          key: :youtube_get_playlist_items,
          name: "YouTube playlist items",
          description: "Reads one page of videos in a public playlist.",
          use_when: "You have a playlist id, including a channel uploads playlist id.",
          do_not_use_when: "You do not know the playlist id yet.",
          parameters: [
            param(:id, :string, true, "YouTube playlist id."),
            param(:max_results, :integer, false, "Page size from 0 to 50. The default is 5."),
            param(:page_token, :string, false, "Token from a previous page.")
          ],
          returns: "A page of playlist items with video ids, titles, URLs, thumbnails, and the next page token.",
          cost: :low,
          executor_label: "RecordingStudio::YouTube.playlist_items"
        ),
        tool(
          key: :youtube_get_comments,
          name: "YouTube comments",
          description: "Reads public comment threads on a video.",
          use_when: "You need published comments for a public video.",
          do_not_use_when: "The video has comments disabled, or you need every reply. " \
                           "A thread may include only some replies.",
          parameters: [
            param(:video_id, :string, true, "YouTube video id."),
            param(:max_results, :integer, false, "Page size from 1 to 100. The default is 20."),
            param(:page_token, :string, false, "Token from a previous page."),
            param(:order, :string, false, "time or relevance."),
            param(:search_terms, :string, false, "Limit comments to text that contains these words.")
          ],
          returns: "A page of comment threads. Each thread has a top-level comment, a reply count, " \
                   "and any replies included on that page.",
          cost: :low,
          executor_label: "RecordingStudio::YouTube.comments"
        )
      ].freeze
    end
  end
end
