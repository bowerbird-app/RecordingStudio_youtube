# frozen_string_literal: true

require "test_helper"
require "json"
require "uri"

class YoutubeApiHttpTest < ActionDispatch::IntegrationTest
  VIDEO_ID = "jNQXAC9IVRw"

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

  test "youtube.search returns 200 for a token with view on the root" do
    transport = SequenceTransport.new([json(200, search_body)])
    with_youtube_transport(transport) do
      get "/recording_studio_api/api/v1/youtube/search",
          params: { query: "zoo", type: "video" },
          headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal VIDEO_ID, payload.fetch("items").first.fetch("video_id")
    assert_equal "search_queries", payload.fetch("quota").first.fetch("bucket")
    assert_equal "/youtube/v3/search", transport.calls.first[:uri].path
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

  test "youtube.search returns 401 without a token" do
    get "/recording_studio_api/api/v1/youtube/search", params: { query: "zoo" }

    assert_response :unauthorized
  end

  test "youtube.search returns 403 when the actor cannot view the root" do
    issued = issue_token_for(@owner, @root)
    RecordingStudio::Access.where(id: issued.fetch(:access_recording).recordable_id).update_all(role: "")
    refute RecordingStudioAccessible.authorized?(
      actor: issued.fetch(:access_recording).recordable.reload.actor,
      recording: @root,
      role: :view
    )

    get "/recording_studio_api/api/v1/youtube/search",
        params: { query: "zoo" },
        headers: bearer_headers(issued.fetch(:token))

    assert_response :forbidden
  end

  test "youtube.search returns 422 for bad params" do
    get "/recording_studio_api/api/v1/youtube/search",
        params: { type: "video" },
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :unprocessable_entity
  end

  test "youtube.search returns forbidden when the search quota is exhausted" do
    transport = SequenceTransport.new([json(403, quota_body)])
    with_youtube_transport(transport) do
      get "/recording_studio_api/api/v1/youtube/search",
          params: { query: "zoo" },
          headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    end

    assert_response :forbidden
    assert_match(/quota/i, JSON.parse(response.body).dig("error", "message").to_s)
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

  def search_body
    {
      "nextPageToken" => "NEXT",
      "pageInfo" => { "totalResults" => 1, "resultsPerPage" => 1 },
      "items" => [
        {
          "id" => { "kind" => "youtube#video", "videoId" => VIDEO_ID },
          "snippet" => {
            "title" => "Me at the zoo",
            "description" => "snippet",
            "channelTitle" => "jawed"
          }
        }
      ]
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
