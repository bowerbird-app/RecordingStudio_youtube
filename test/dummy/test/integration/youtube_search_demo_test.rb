# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "json"

class YoutubeSearchDemoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "youtube-search-demo@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
  end

  test "home page is a search form and does not call youtube without a query" do
    transport = RecordingTransport.new

    with_youtube_transport(transport) do
      get root_path
    end

    assert_response :success
    assert_empty transport.calls
    assert_select "input[name='q']"
    assert_includes response.body, "YouTube search"
    assert_includes response.body, "Enter a search to see public YouTube results."
    refute_includes response.body, "What's working"
  end

  test "home page renders the youtube results that were returned" do
    transport = RecordingTransport.new(search_response("Me at the &#39;zoo&#39;", "jawed", "abc123def45"))

    with_youtube_transport(transport) do
      get root_path, params: { q: "zoo" }
    end

    assert_response :success
    assert_select "input[name='q'][value='zoo']"
    assert_includes response.body, "Me at the &#39;zoo&#39;"
    refute_includes response.body, "&amp;#39;"
    assert_includes response.body, "jawed"
    assert_includes response.body, "https://www.youtube.com/watch?v=abc123def45"
    assert_includes response.body, "https://img.example/medium.jpg"
    assert_includes response.body, "1 result"
  end

  test "home page shows the next page link when youtube returns one" do
    transport = RecordingTransport.new(
      search_response("Me at the zoo", "jawed", "abc123def45", next_page_token: "NEXT")
    )

    with_youtube_transport(transport) do
      get root_path, params: { q: "zoo" }
    end

    assert_includes response.body, "page_token=NEXT"
  end

  test "home page shows a youtube error instead of an empty result list" do
    transport = RecordingTransport.new(
      RecordingStudio::YouTube::ConfigurationError.new("YouTube API key is not configured")
    )

    with_youtube_transport(transport) do
      get root_path, params: { q: "zoo" }
    end

    assert_response :success
    assert_includes response.body, "YouTube API key is not configured"
    refute_includes response.body, "No results for"
  end

  private

  class RecordingTransport
    attr_reader :calls

    def initialize(response = nil)
      @response = response
      @calls = []
    end

    def perform(uri, headers, _timeouts)
      @calls << { uri: uri, headers: headers }
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  def with_youtube_transport(transport)
    configuration = RecordingStudio::YouTube.configuration
    previous = {
      transport: configuration.transport,
      api_key: configuration.api_key,
      retries: configuration.retries,
      retry_wait: configuration.retry_wait,
      instrumentation_enabled: configuration.instrumentation_enabled
    }

    RecordingStudio::YouTube.configure do |config|
      config.transport = transport
      config.api_key = "test-key"
      config.retries = 0
      config.retry_wait = 0
      config.instrumentation_enabled = false
    end

    yield
  ensure
    RecordingStudio::YouTube.configure do |config|
      config.transport = previous[:transport]
      config.api_key = previous[:api_key]
      config.retries = previous[:retries]
      config.retry_wait = previous[:retry_wait]
      config.instrumentation_enabled = previous[:instrumentation_enabled]
    end
  end

  def search_response(title, channel, video_id, next_page_token: nil)
    body = {
      "pageInfo" => { "totalResults" => 1, "resultsPerPage" => 1 },
      "items" => [
        {
          "id" => { "kind" => "youtube#video", "videoId" => video_id },
          "snippet" => {
            "title" => title,
            "description" => "The first video",
            "channelTitle" => channel,
            "thumbnails" => {
              "medium" => { "url" => "https://img.example/medium.jpg", "width" => 320, "height" => 180 }
            }
          }
        }
      ]
    }
    body["nextPageToken"] = next_page_token if next_page_token
    [200, JSON.generate(body), { "content-type" => "application/json" }]
  end
end
