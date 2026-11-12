# frozen_string_literal: true

require "test_helper"
require "json"

class YoutubeApiHttpTest < ActionDispatch::IntegrationTest
  VIDEO_ID = "jNQXAC9IVRw"
  PLAYLIST_ID = "PL1234567890abcdef"

  setup do
    @owner = User.find_or_create_by!(email: "youtube-api-http-owner@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
    end
    @root = DummyAccess.bootstrap_workspace!(name: "YouTube API HTTP Workspace", actor: @owner)
    @previous = {
      transport: RecordingStudio::YouTube.configuration.transport,
      api_key: RecordingStudio::YouTube.configuration.api_key,
      retries: RecordingStudio::YouTube.configuration.retries,
      retry_wait: RecordingStudio::YouTube.configuration.retry_wait,
      instrumentation_enabled: RecordingStudio::YouTube.configuration.instrumentation_enabled
    }
  end

  teardown do
    RecordingStudio::YouTube.configure do |config|
      config.transport = @previous[:transport]
      config.api_key = @previous[:api_key]
      config.retries = @previous[:retries]
      config.retry_wait = @previous[:retry_wait]
      config.instrumentation_enabled = @previous[:instrumentation_enabled]
    end
  end

  test "youtube.get_video returns 200 for a stubbed video" do
    transport = SequenceTransport.new([json(200, video_body)])
    with_youtube_transport(transport) do
      get "/recording_studio_api/api/v1/youtube/videos/#{VIDEO_ID}",
          headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    end

    assert_response :success
    assert_equal VIDEO_ID, JSON.parse(response.body).fetch("id")
  end

  test "youtube.get_video returns 401 without a token" do
    get "/recording_studio_api/api/v1/youtube/videos/#{VIDEO_ID}"

    assert_response :unauthorized
  end

  test "youtube.get_video returns 403 when the actor cannot view the root" do
    issued = issue_token_for(@owner, @root)
    RecordingStudio::Access.where(id: issued.fetch(:access_recording).recordable_id).update_all(role: "")
    refute RecordingStudioAccessible.authorized?(
      actor: issued.fetch(:access_recording).recordable.reload.actor,
      recording: @root,
      role: :view
    )

    get "/recording_studio_api/api/v1/youtube/videos/#{VIDEO_ID}",
        headers: bearer_headers(issued.fetch(:token))

    assert_response :forbidden
  end

  test "youtube.get_video returns 422 for bad params" do
    get "/recording_studio_api/api/v1/youtube/videos/bad%20id",
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :unprocessable_entity
  end

  test "youtube.get_video returns forbidden when the quota is exhausted" do
    transport = SequenceTransport.new([json(403, quota_body)])
    with_youtube_transport(transport) do
      get "/recording_studio_api/api/v1/youtube/videos/#{VIDEO_ID}",
          headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    end

    assert_response :forbidden
    assert_match(/quota/i, JSON.parse(response.body).dig("error", "message").to_s)
  end

  test "youtube.get_playlist_items walks two dummy HTTP pages" do
    next_token = "PAGE_TWO"
    transport = SequenceTransport.new([
      json(200, playlist_items_body(item_id: "item-page-1", next_page_token: next_token)),
      json(200, playlist_items_body(item_id: "item-page-2"))
    ])
    headers = bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    path = "/recording_studio_api/api/v1/youtube/playlists/#{PLAYLIST_ID}/items"

    with_youtube_transport(transport) do
      get path, params: { max_results: 1 }, headers: headers
      assert_response :success
      first_page = JSON.parse(response.body)
      first_ids = first_page.fetch("items").map { |item| item.fetch("id") }
      assert_equal next_token, first_page.fetch("next_page_token")

      get path, params: { max_results: 1, page_token: first_page.fetch("next_page_token") }, headers: headers
      assert_response :success
      second_page = JSON.parse(response.body)
      second_ids = second_page.fetch("items").map { |item| item.fetch("id") }
      assert_nil second_page["next_page_token"]
      assert_empty first_ids & second_ids
      refute_empty first_ids
      refute_empty second_ids
    end

    assert_equal 2, transport.calls.length
    refute query(transport.calls[0][:uri]).key?("pageToken")
    assert_equal next_token, query(transport.calls[1][:uri]).fetch("pageToken")
  end

  private

  class SequenceTransport
    attr_reader :calls

    def initialize(responses)
      @responses = responses.dup
      @calls = []
    end

    def perform(uri, headers, _timeouts)
      @calls << { uri: uri, headers: headers }
      @responses.shift
    end
  end

  def with_youtube_transport(transport)
    RecordingStudio::YouTube.configure do |config|
      config.transport = transport
      config.api_key = "test-key"
      config.retries = 0
      config.retry_wait = 0
      config.instrumentation_enabled = false
    end

    yield
  end

  def json(status, body)
    [status, JSON.generate(body), { "content-type" => "application/json" }]
  end

  def query(uri)
    URI.decode_www_form(uri.query.to_s).to_h
  end

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def access_recording_for(actor, root)
    RecordingStudioAccessible.access_recordings_for_actor(recording: root, actor: actor).first
  end

  def issue_token_for(actor, root)
    access_recording = access_recording_for(actor, root)
    raise "missing access recording" if access_recording.blank?

    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: root,
      manager_actor: actor,
      role: access_recording.recordable.role,
      name: "YouTube HTTP client #{SecureRandom.hex(4)}"
    )
    raise provision.error unless provision.success?

    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise token_result.error unless token_result.success?

    {
      token: token_result.value.fetch(:access_token),
      access_recording: provision.value.fetch(:access_recording)
    }
  end

  def playlist_items_body(item_id:, next_page_token: nil)
    body = {
      "pageInfo" => { "totalResults" => 2, "resultsPerPage" => 1 },
      "items" => [
        {
          "id" => item_id,
          "snippet" => {
            "title" => "Me at the zoo",
            "description" => "item",
            "channelId" => "UC4QobU6STFB0P71PMvOGN5A",
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
    body["nextPageToken"] = next_page_token unless next_page_token.nil?
    body
  end

  def video_body
    {
      "items" => [
        {
          "id" => VIDEO_ID,
          "snippet" => {
            "title" => "Me at the zoo",
            "description" => "The first video",
            "channelId" => "UC4QobU6STFB0P71PMvOGN5A",
            "channelTitle" => "jawed",
            "publishedAt" => "2005-04-24T03:31:52Z"
          },
          "contentDetails" => { "duration" => "PT19S" },
          "statistics" => { "viewCount" => "1" }
        }
      ]
    }
  end

  def quota_body
    {
      "error" => {
        "code" => 403,
        "message" => "The request cannot be completed because you have exceeded your quota.",
        "errors" => [{
          "message" => "The request cannot be completed because you have exceeded your quota.",
          "domain" => "youtube.quota",
          "reason" => "quotaExceeded"
        }]
      }
    }
  end
end
