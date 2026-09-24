# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

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
    called = false
    with_youtube_search(->(**) { called = true }) do
      get root_path
    end

    assert_response :success
    assert_not called
    assert_select "input[name='q']"
    assert_includes response.body, "YouTube search"
    assert_includes response.body, "Enter a search to see public YouTube results."
    refute_includes response.body, "What's working"
  end

  test "home page renders the youtube results that were returned" do
    page = search_page("Me at the &#39;zoo&#39;", "jawed", "abc123def45")

    with_youtube_search(page) do
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
    page = search_page("Me at the zoo", "jawed", "abc123def45", next_page_token: "NEXT")

    with_youtube_search(page) do
      get root_path, params: { q: "zoo" }
    end

    assert_includes response.body, "page_token=NEXT"
  end

  test "home page shows a youtube error instead of an empty result list" do
    raise_error = ->(**) { raise RecordingStudio::YouTube::ConfigurationError, "YouTube API key is not configured" }

    with_youtube_search(raise_error) do
      get root_path, params: { q: "zoo" }
    end

    assert_response :success
    assert_includes response.body, "YouTube API key is not configured"
    refute_includes response.body, "No results for"
  end

  private

  def with_youtube_search(replacement)
    owner = RecordingStudio::YouTube.singleton_class
    owner.alias_method(:search_without_test_double, :search)
    owner.define_method(:search) do |**kwargs|
      replacement.respond_to?(:call) ? replacement.call(**kwargs) : replacement
    end
    yield
  ensure
    owner.alias_method(:search, :search_without_test_double)
    owner.remove_method(:search_without_test_double)
  end

  def search_page(title, channel, video_id, next_page_token: nil)
    item = RecordingStudio::YouTube::SearchItem.from_api(
      "id" => { "kind" => "youtube#video", "videoId" => video_id },
      "snippet" => {
        "title" => title,
        "description" => "The first video",
        "channelTitle" => channel,
        "thumbnails" => {
          "medium" => { "url" => "https://img.example/medium.jpg", "width" => 320, "height" => 180 }
        }
      }
    )
    RecordingStudio::YouTube::Page.new(
      items: [item],
      next_page_token: next_page_token,
      total_results: 1,
      results_per_page: 1,
      raw: {}
    )
  end
end
