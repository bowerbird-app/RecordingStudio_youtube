# frozen_string_literal: true

require "test_helper"
require "json"
require "uri"

class YoutubeApiTest < Minitest::Test
  VIDEO_ID = "jNQXAC9IVRw"
  CHANNEL_ID = "UC4QobU6STFB0P71PMvOGN5A"
  PLAYLIST_ID = "PL1234567890abcdef"

  def setup
    @previous = RecordingStudio::YouTube.instance_variable_get(:@configuration)
  end

  def teardown
    RecordingStudio::YouTube.instance_variable_set(:@configuration, @previous)
  end

  def test_video_parses_metadata_thumbnails_and_duration
    transport = sequence(
      json(200, video_body)
    )
    with_transport(transport) do
      video = RecordingStudio::YouTube.video(VIDEO_ID)
      assert_equal VIDEO_ID, video.id
      assert_equal "Me at the zoo", video.title
      assert_equal "jawed", video.channel_title
      assert_equal CHANNEL_ID, video.channel_id
      assert_equal "https://www.youtube.com/watch?v=#{VIDEO_ID}", video.url
      assert_equal "PT19S", video.duration
      assert_equal 19, video.duration_seconds
      assert_equal ["zoo"], video.tags
      assert_equal 1, video.statistics.view_count
      assert_nil video.statistics.like_count
      thumbnail = video.thumbnails["high"]
      assert_equal "https://img.example/high.jpg", thumbnail.url
      assert_equal 480, thumbnail.width
      assert_equal 360, thumbnail.height
      assert_equal "high", video.thumbnails.primary.variant
      assert_equal video_body["items"].first, video.raw
      refute video.raw.key?("liveStreamingDetails")
      assert_nil video.live_streaming_details.actual_start_time
    end
    assert_equal "/youtube/v3/videos", transport.calls.first[:uri].path
    assert_equal "test-key", query(transport.calls.first[:uri])["key"]
    refute transport.calls.first[:headers].key?("Authorization")
  end

  def test_missing_video_is_not_found_without_inventing_fields
    transport = sequence(json(200, { "items" => [] }))
    with_transport(transport) do
      error = assert_raises(RecordingStudio::YouTube::NotFoundError) do
        RecordingStudio::YouTube.video("deletedvid1")
      end
      assert_equal "notFound", error.reason
      assert_equal "videos.list", error.operation
    end
  end

  def test_invalid_video_id_does_not_call_youtube
    transport = sequence(json(200, { "items" => [] }))
    with_transport(transport) do
      assert_raises(RecordingStudio::YouTube::InvalidRequestError) do
        RecordingStudio::YouTube.video("bad id")
      end
    end
    assert_empty transport.calls
  end

  def test_search_returns_lightweight_items_and_stops_at_one_page
    transport = sequence(json(200, search_body))
    with_transport(transport) do
      result = RecordingStudio::YouTube.search(query: "zoo", type: :video, max_results: 2)
      item = result.items.first
      assert_instance_of RecordingStudio::YouTube::SearchItem, item
      assert_equal VIDEO_ID, item.video_id
      assert_equal "Me at the zoo", item.title
      assert_equal "https://www.youtube.com/watch?v=#{VIDEO_ID}", item.url
      assert_equal "NEXT", result.next_page_token
      assert_equal "PREV", result.previous_page_token
      assert result.more?
      assert_nil result.instance_variable_get(:@videos_by_id) if result.respond_to?(:videos_by_id)
      refute_respond_to item, :duration
    end
    assert_equal 1, transport.calls.length
    params = query(transport.calls.first[:uri])
    assert_equal "zoo", params["q"]
    assert_equal "video", params["type"]
    assert_equal "2", params["maxResults"]
    assert_equal "snippet", params["part"]
  end

  def test_provider_params_cannot_replace_validated_search_fields
    blocked = sequence(json(200, search_body))
    with_transport(blocked) do
      error = assert_raises(RecordingStudio::YouTube::InvalidRequestError) do
        RecordingStudio::YouTube.search(query: "zoo", max_results: 2, provider_params: { maxResults: "50", q: "other" })
      end
      assert_includes error.message, "cannot set"
    end
    assert_empty blocked.calls

    allowed = sequence(json(200, search_body))
    with_transport(allowed) do
      RecordingStudio::YouTube.search(query: "zoo", max_results: 2, provider_params: { videoDefinition: "high" })
    end
    params = query(allowed.calls.first[:uri])
    assert_equal "zoo", params["q"]
    assert_equal "2", params["maxResults"]
    assert_equal "snippet", params["part"]
    assert_equal "high", params["videoDefinition"]
  end

  def test_channel_videos_skip_the_channel_lookup_when_the_playlist_id_is_known
    transport = sequence(json(200, playlist_items_body))
    with_transport(transport) do
      page = RecordingStudio::YouTube.channel_videos(
        uploads_playlist_id: PLAYLIST_ID, page_token: "TOKEN", max_results: 1
      )
      assert_equal VIDEO_ID, page.items.first.video_id
      assert_equal PLAYLIST_ID, page.uploads_playlist_id
      assert_nil page.channel_id
      assert_equal %w[playlistItems.list], page.quota.map(&:operation)
      assert_equal 1, page.requests
    end
    assert_equal 1, transport.calls.length
    assert_equal "/youtube/v3/playlistItems", transport.calls.first[:uri].path
    assert_equal PLAYLIST_ID, query(transport.calls.first[:uri])["playlistId"]
  end

  def test_search_enrichment_is_one_extra_videos_call
    transport = sequence(
      json(200, search_body),
      json(200, video_body)
    )
    with_transport(transport) do
      result = RecordingStudio::YouTube.search(query: "zoo", type: :video, enrich: :videos)
      assert_instance_of RecordingStudio::YouTube::SearchItem, result.items.first
      assert_equal 19, result.videos_by_id.fetch(VIDEO_ID).duration_seconds
      assert_equal %w[search.list videos.list], result.quota.map(&:operation)
      assert_equal 2, result.requests
    end
    assert_equal "/youtube/v3/videos", transport.calls.last[:uri].path
    assert_equal VIDEO_ID, query(transport.calls.last[:uri])["id"]
  end

  def test_channel_and_channel_videos_use_the_uploads_playlist
    transport = sequence(
      json(200, channel_body),
      json(200, channel_body),
      json(200, playlist_items_body)
    )
    with_transport(transport) do
      channel = RecordingStudio::YouTube.channel(CHANNEL_ID)
      assert_equal "jawed", channel.title
      assert_equal "UU4QobU6STFB0P71PMvOGN5A", channel.uploads_playlist_id
      assert_equal "https://www.youtube.com/channel/#{CHANNEL_ID}", channel.url
      assert_equal "https://www.youtube.com/@jawed", channel.handle_url
      assert_equal 480, channel.thumbnails.primary.width

      page = RecordingStudio::YouTube.channel_videos(channel_id: CHANNEL_ID, max_results: 1)
      assert_equal VIDEO_ID, page.items.first.video_id
      assert_equal "UU4QobU6STFB0P71PMvOGN5A", page.uploads_playlist_id
      assert_equal "TOKEN", page.next_page_token
      assert page.more?
      assert_equal %w[channels.list playlistItems.list], page.quota.map(&:operation)
      assert_equal 2, page.requests
    end
    assert_equal "/youtube/v3/channels", transport.calls[1][:uri].path
    item_params = query(transport.calls[2][:uri])
    assert_equal "/youtube/v3/playlistItems", transport.calls[2][:uri].path
    assert_equal "UU4QobU6STFB0P71PMvOGN5A", item_params["playlistId"]
    refute_equal "/youtube/v3/search", transport.calls[2][:uri].path
  end

  def test_channel_handle_lookup
    transport = sequence(json(200, channel_body))
    with_transport(transport) do
      channel = RecordingStudio::YouTube.channel(handle: "@jawed")
      assert_equal CHANNEL_ID, channel.id
    end
    assert_equal "jawed", query(transport.calls.first[:uri])["forHandle"]
  end

  def test_playlist_and_items
    transport = sequence(
      json(200, playlist_body),
      json(200, playlist_items_body)
    )
    with_transport(transport) do
      playlist = RecordingStudio::YouTube.playlist(PLAYLIST_ID)
      assert_equal "Uploads", playlist.title
      assert_equal 3, playlist.item_count
      assert_equal "https://www.youtube.com/playlist?list=#{PLAYLIST_ID}", playlist.url
      page = RecordingStudio::YouTube.playlist_items(PLAYLIST_ID, page_token: "TOKEN")
      assert_equal "Me at the zoo", page.items.first.title
    end
    assert_equal "TOKEN", query(transport.calls.last[:uri])["pageToken"]
  end

  def test_comments_keep_threads_and_replies_distinct
    transport = sequence(json(200, comments_body))
    with_transport(transport) do
      page = RecordingStudio::YouTube.comments(video_id: VIDEO_ID, max_results: 20)
      thread = page.items.first
      assert_equal "Top comment", thread.top_level.text
      assert_equal 2, thread.total_reply_count
      assert_equal 1, thread.replies.length
      assert_equal "A reply", thread.replies.first.text
      refute thread.to_agent["replies_complete"]
      assert_equal "plainText", query(transport.calls.first[:uri])["textFormat"]
    end
  end

  def test_bearer_auth_omits_the_api_key
    connection = Struct.new(:access_token).new("user-token")
    transport = sequence(json(200, channel_body))
    with_transport(transport) do
      channel = RecordingStudio::YouTube.for(connection).channel(mine: true)
      assert_equal CHANNEL_ID, channel.id
    end
    params = query(transport.calls.first[:uri])
    refute params.key?("key")
    assert_equal "true", params["mine"]
    assert_equal "Bearer user-token", transport.calls.first[:headers]["Authorization"]
  end

  def test_quota_authentication_and_network_errors_hide_secrets
    secret = "test-key"
    transport = sequence(
      json(403, google_error(403, "quotaExceeded", "youtube.quota", "blocked #{secret}")),
      json(401, google_error(401, "authError", "global", "bad #{secret}")),
      json(403, google_error(403, "commentsDisabled", "youtube.comment", "disabled")),
      json(400, google_error(400, "invalidSearchFilter", "youtube.search", "bad filter"))
    )
    with_transport(transport) do
      quota = assert_raises(RecordingStudio::YouTube::QuotaExceededError) { RecordingStudio::YouTube.video(VIDEO_ID) }
      auth = assert_raises(RecordingStudio::YouTube::AuthenticationError) { RecordingStudio::YouTube.video(VIDEO_ID) }
      comments = assert_raises(RecordingStudio::YouTube::AuthorizationError) do
        RecordingStudio::YouTube.comments(video_id: VIDEO_ID)
      end
      invalid = assert_raises(RecordingStudio::YouTube::InvalidRequestError) do
        RecordingStudio::YouTube.search(query: "zoo")
      end
      [quota, auth, comments, invalid].each do |error|
        refute_includes error.message, secret
        refute_includes error.details.inspect, secret
      end
      assert_equal "blocked [redacted]", quota.details.first["message"]
      assert_equal "bad [redacted]", auth.details.first["message"]
      assert_equal "quotaExceeded", quota.reason
      assert_equal "commentsDisabled", comments.reason
      assert_equal "invalidSearchFilter", invalid.reason
    end
    assert_equal 4, transport.calls.length
  end

  def test_rate_limit_and_retry_behavior
    secret = "test-key"
    rate = sequence(json(403, google_error(403, "rateLimitExceeded", "youtube.quota", secret)))
    with_transport(rate, retries: 2) do
      error = assert_raises(RecordingStudio::YouTube::RateLimitError) { RecordingStudio::YouTube.video(VIDEO_ID) }
      refute_includes error.message, secret
    end
    assert_equal 1, rate.calls.length

    retried = sequence(
      json(503, "unavailable"),
      json(200, video_body)
    )
    with_transport(retried, retries: 1) do
      assert_equal "Me at the zoo", RecordingStudio::YouTube.video(VIDEO_ID).title
    end
    assert_equal 2, retried.calls.length

    offline = sequence(SocketError.new("offline"))
    with_transport(offline) do
      error = assert_raises(RecordingStudio::YouTube::NetworkError) { RecordingStudio::YouTube.video(VIDEO_ID) }
      refute_includes error.message, secret
    end
  end

  def test_missing_api_key_fails_before_a_request
    transport = sequence(json(200, video_body))
    with_transport(transport, api_key: nil) do
      error = assert_raises(RecordingStudio::YouTube::ConfigurationError) do
        RecordingStudio::YouTube.video(VIDEO_ID)
      end
      refute_includes error.message, "test-key"
    end
    assert_empty transport.calls
  end

  def test_capability_metadata_is_centralized
    search = RecordingStudio::YouTube.capability(:search)
    upload = RecordingStudio::YouTube.capability(:upload_video)
    captions = RecordingStudio::YouTube.capability(:download_caption)
    assert search.read?
    assert_equal %i[api_key user], search.authentication
    assert_equal 1, search.quota.units
    assert_equal "search_queries", search.quota.bucket
    assert_equal 100, search.quota.daily_limit
    assert_equal RecordingStudio::YouTube::Quota.fetch("search.list"), search.quota
    assert upload.write?
    refute upload.implemented
    assert_includes upload.scopes, "https://www.googleapis.com/auth/youtube.upload"
    assert captions.read?
    assert_equal [:user], captions.authentication
    assert_nil captions.quota.units
    refute_respond_to RecordingStudio::YouTube, :upload_video
    refute_respond_to RecordingStudio::YouTube, :transcript
  end

  def test_oauth_url_carries_youtube_scopes_and_not_a_client_secret
    configuration = RecordingStudio::YouTube::Configuration.new
    configuration.api_key = "test-key"
    configuration.oauth_client_id = "client-id"
    RecordingStudio::YouTube.instance_variable_set(:@configuration, configuration)
    url = RecordingStudio::YouTube::Oauth.authorization_url(
      redirect_uri: "https://app.example/callback",
      state: "state-token",
      scopes: RecordingStudio::YouTube::Oauth.scopes_for(:get_mine_channel)
    )
    params = URI.decode_www_form(URI(url).query).to_h
    assert_equal "https://accounts.google.com/o/oauth2/v2/auth", url.split("?").first
    assert_equal "client-id", params["client_id"]
    assert_equal "https://www.googleapis.com/auth/youtube.readonly", params["scope"]
    assert_equal "state-token", params["state"]
    assert_equal "code", params["response_type"]
    refute params.key?("client_secret")
    refute_includes url, "client_secret"
    assert_equal "https://oauth2.googleapis.com/token", RecordingStudio::YouTube::Oauth::TOKEN_ENDPOINT
    refute RecordingStudio::YouTube::Oauth.respond_to?(:exchange)
  end

  def test_caption_download_requires_the_same_client_and_does_not_pretend_to_be_public
    transport = sequence([200, "WEBVTT", { "content-type" => "text/vtt" }])
    connection = { "access_token" => "user-token" }
    with_transport(transport) do
      download = RecordingStudio::YouTube.download_caption("caption1", format: "vtt", connection: connection)
      assert_equal "WEBVTT", download.body
      assert_equal "text/vtt", download.content_type
    end
    assert_equal "/youtube/v3/captions/caption1", transport.calls.first[:uri].path
    assert_equal "vtt", query(transport.calls.first[:uri])["tfmt"]
    refute query(transport.calls.first[:uri]).key?("key")
  end

  def test_instrumentation_omits_credentials
    transport = sequence(json(200, video_body))
    events = []
    subscription = ActiveSupport::Notifications.subscribe(RecordingStudio::YouTube::Client::EVENT_NAME) do |*args|
      events << args.last
    end
    with_transport(transport, instrumentation: true) do
      RecordingStudio::YouTube.video(VIDEO_ID)
    end
    payload = events.last
    assert_equal "videos.list", payload[:operation]
    assert_equal "videos", payload[:endpoint]
    assert_equal :api_key, payload[:authentication_type]
    assert_equal 1, payload[:request_count]
    assert_equal 1, payload[:quota_units]
    assert_equal "standard", payload[:quota_bucket]
    refute_includes payload.inspect, "test-key"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  def test_diagnostics_do_not_include_secret_values
    with_transport(sequence(json(200, video_body)), api_key: "test-key") do
      RecordingStudio::YouTube.configuration.oauth_client_id = nil
      quiet = RecordingStudio::YouTube.diagnostics
      probed = RecordingStudio::YouTube.diagnostics(probe: true)
      assert_equal "configured", quiet["YouTube Data API key"]
      assert_equal "unavailable", quiet["Google OAuth client ID"]
      refute quiet.key?("Google OAuth client secret")
      assert_equal "not checked", quiet["Public API access"]
      assert_equal "working", probed["Public API access"]
      refute_includes quiet.inspect, "test-key"
      refute_includes probed.inspect, "test-key"
    end
  end

  def test_ai_tools_are_read_only_and_return_concise_pages
    keys = RecordingStudio::YouTube::AiTools.definitions.map { |definition| definition[:key] }
    assert_equal %i[
      youtube_search youtube_get_video youtube_get_channel youtube_get_channel_videos
      youtube_get_playlist youtube_get_playlist_items youtube_get_comments
    ], keys
    search = RecordingStudio::YouTube::AiTools.definitions.first
    RecordingStudio::YouTube::AiTools.definitions.each do |definition|
      assert_equal true, definition[:read_only]
      assert_equal false, definition[:destructive]
      assert_includes %i[negligible low medium high], definition[:cost]
    end
    assert_equal :high, search[:cost]
    assert_equal true, search[:requires_confirmation]
    RecordingStudio::YouTube::AiTools.definitions.drop(1).each do |definition|
      assert_equal false, definition[:requires_confirmation]
    end
    channel_videos = RecordingStudio::YouTube::AiTools.definitions.find { |item| item[:key] == :youtube_get_channel_videos }
    parameter_names = channel_videos[:parameters].map { |parameter| parameter[:name] }
    assert_includes parameter_names, :uploads_playlist_id

    transport = sequence(json(200, search_body), json(200, search_body))
    with_transport(transport) do
      executor = search[:executor]
      payload = executor.call({ "query" => "zoo", "type" => "video" }, nil)
      symbol_payload = executor.call({ query: "zoo", type: :video }, nil)
      assert_equal VIDEO_ID, payload["items"].first["video_id"]
      assert_equal payload["items"].first["video_id"], symbol_payload["items"].first["video_id"]
      assert_equal "NEXT", payload["next_page_token"]
      assert_equal true, payload["more"]
      assert_equal "search_queries", payload["quota"].first["bucket"]
      refute payload["items"].first.key?("raw")
    end
  end

  class FakeTransport
    attr_reader :calls

    def initialize(responses)
      @responses = responses.dup
      @calls = []
    end

    def perform(uri, headers, _timeouts)
      @calls << { uri: uri, headers: headers }
      response = @responses.shift
      raise response if response.is_a?(Exception)

      response.call if response.respond_to?(:call)
      response
    end
  end

  def sequence(*responses)
    FakeTransport.new(responses)
  end

  def json(status, body)
    [status, body.is_a?(String) ? body : JSON.generate(body), { "content-type" => "application/json" }]
  end

  def with_transport(transport, api_key: "test-key", retries: 0, instrumentation: false)
    configuration = RecordingStudio::YouTube::Configuration.new
    configuration.api_key = api_key
    configuration.oauth_client_id = nil
    configuration.transport = transport
    configuration.retries = retries
    configuration.retry_wait = 0
    configuration.instrumentation_enabled = instrumentation
    RecordingStudio::YouTube.instance_variable_set(:@configuration, configuration)
    yield
  end

  def query(uri)
    URI.decode_www_form(uri.query.to_s).to_h
  end

  def google_error(status, reason, domain, message)
    {
      "error" => {
        "code" => status,
        "message" => message,
        "errors" => [{ "message" => message, "domain" => domain, "reason" => reason }]
      }
    }
  end

  def video_body
    {
      "items" => [
        {
          "id" => VIDEO_ID,
          "snippet" => {
            "title" => "Me at the zoo",
            "description" => "The first video",
            "channelId" => CHANNEL_ID,
            "channelTitle" => "jawed",
            "publishedAt" => "2005-04-24T03:31:52Z",
            "categoryId" => "22",
            "tags" => ["zoo"],
            "thumbnails" => {
              "default" => { "url" => "https://img.example/default.jpg", "width" => 120, "height" => 90 },
              "high" => { "url" => "https://img.example/high.jpg", "width" => 480, "height" => 360 }
            }
          },
          "contentDetails" => { "duration" => "PT19S" },
          "statistics" => { "viewCount" => "1" },
          "status" => { "privacyStatus" => "public" }
        }
      ]
    }
  end

  def search_body
    {
      "nextPageToken" => "NEXT",
      "prevPageToken" => "PREV",
      "regionCode" => "US",
      "pageInfo" => { "totalResults" => 1, "resultsPerPage" => 1 },
      "items" => [
        {
          "id" => { "kind" => "youtube#video", "videoId" => VIDEO_ID },
          "snippet" => {
            "title" => "Me at the zoo",
            "description" => "snippet",
            "channelId" => CHANNEL_ID,
            "channelTitle" => "jawed",
            "publishedAt" => "2005-04-24T03:31:52Z",
            "thumbnails" => {
              "default" => { "url" => "https://img.example/default.jpg", "width" => 120, "height" => 90 }
            }
          }
        }
      ]
    }
  end

  def channel_body
    {
      "items" => [
        {
          "id" => CHANNEL_ID,
          "snippet" => {
            "title" => "jawed",
            "description" => "channel",
            "customUrl" => "@jawed",
            "publishedAt" => "2005-04-23T00:00:00Z",
            "country" => "US",
            "thumbnails" => {
              "high" => { "url" => "https://img.example/channel.jpg", "width" => 480, "height" => 360 }
            }
          },
          "statistics" => { "subscriberCount" => "10", "viewCount" => "20", "videoCount" => "1" },
          "contentDetails" => { "relatedPlaylists" => { "uploads" => "UU4QobU6STFB0P71PMvOGN5A" } }
        }
      ]
    }
  end

  def playlist_body
    {
      "items" => [
        {
          "id" => PLAYLIST_ID,
          "snippet" => {
            "title" => "Uploads",
            "description" => "playlist",
            "channelId" => CHANNEL_ID,
            "channelTitle" => "jawed",
            "publishedAt" => "2005-04-23T00:00:00Z"
          },
          "contentDetails" => { "itemCount" => 3 }
        }
      ]
    }
  end

  def playlist_items_body
    {
      "nextPageToken" => "TOKEN",
      "pageInfo" => { "totalResults" => 1, "resultsPerPage" => 1 },
      "items" => [
        {
          "id" => "item1",
          "snippet" => {
            "title" => "Me at the zoo",
            "description" => "item",
            "channelId" => CHANNEL_ID,
            "channelTitle" => "jawed",
            "publishedAt" => "2005-04-24T03:31:52Z",
            "position" => 0,
            "thumbnails" => {
              "default" => { "url" => "https://img.example/default.jpg", "width" => 120, "height" => 90 }
            }
          },
          "contentDetails" => { "videoId" => VIDEO_ID }
        }
      ]
    }
  end

  def comments_body
    {
      "items" => [
        {
          "id" => "thread1",
          "snippet" => {
            "videoId" => VIDEO_ID,
            "totalReplyCount" => 2,
            "topLevelComment" => {
              "id" => "comment1",
              "snippet" => {
                "textDisplay" => "Top comment",
                "authorDisplayName" => "Ada",
                "authorChannelId" => { "value" => CHANNEL_ID },
                "likeCount" => 4,
                "publishedAt" => "2020-01-01T00:00:00Z",
                "videoId" => VIDEO_ID
              }
            }
          },
          "replies" => {
            "comments" => [
              {
                "id" => "reply1",
                "snippet" => {
                  "textDisplay" => "A reply",
                  "parentId" => "comment1",
                  "authorDisplayName" => "Grace",
                  "likeCount" => 0,
                  "publishedAt" => "2020-01-02T00:00:00Z"
                }
              }
            ]
          }
        }
      ]
    }
  end
end
