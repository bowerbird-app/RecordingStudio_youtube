# frozen_string_literal: true

require "test_helper"

class LiveYoutubeTest < Minitest::Test
  VIDEO_ID = "jNQXAC9IVRw"

  def setup
    skip "Set YOUTUBE_LIVE=1 to run read-only YouTube Data API checks" unless ENV["YOUTUBE_LIVE"] == "1"

    RecordingStudio::YouTube.instance_variable_set(:@configuration, nil)
  end

  def test_public_read_against_the_data_api
    video = RecordingStudio::YouTube.video(VIDEO_ID)
    channel = RecordingStudio::YouTube.channel(video.channel_id)
    videos = RecordingStudio::YouTube.channel_videos(channel_id: channel.id, max_results: 1)
    search = RecordingStudio::YouTube.search(query: "me at the zoo", type: :video, max_results: 1)
    comments = RecordingStudio::YouTube.comments(video_id: VIDEO_ID, max_results: 1)

    assert_equal VIDEO_ID, video.id
    assert_equal "Me at the zoo", video.title
    assert_equal video.channel_id, channel.id
    refute_nil video.url
    refute_nil channel.uploads_playlist_id
    refute_empty videos.items
    refute_empty search.items
    assert_instance_of RecordingStudio::YouTube::Page, comments
    assert_kind_of Hash, comments.raw
    assert comments.raw.key?("items")
    assert comments.items.all?(RecordingStudio::YouTube::CommentThread)
    puts "live video=#{video.id} channel=#{channel.id} uploads=#{videos.items.length} " \
         "search=#{search.items.length} comments=#{comments.items.length}"
  end
end
