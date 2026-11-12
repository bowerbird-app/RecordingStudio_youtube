# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ApiTest < Minitest::Test
  class FakeGrant
    def initialize(authorized: true)
      @authorized = authorized
    end

    def authorize!(recording:, role:, **)
      raise RecordingStudioApi::AuthorizationError, "API access grant is not authorized for this capability" unless
        @authorized
      raise "view role required" unless role == :view
      raise "root recording required" if recording.nil?
    end
  end

  class FakeContext
    def initialize(params: {}, root_recording: :root, authorized: true)
      @access_grant = FakeGrant.new(authorized: authorized)
      @params = params
      @root_recording = root_recording
    end

    attr_reader :access_grant, :params, :root_recording
  end

  def test_gemspec_omits_runtime_recording_studio_api_dependency
    gemspec = File.read(File.expand_path("../recording_studio_youtube.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
    refute_includes gemspec, 'spec.add_development_dependency "recording_studio_api"'
    assert_includes gemfile, "recording_studio_api"
  end

  def test_engine_registers_api_when_present
    engine = File.read(File.expand_path("../lib/recording_studio_youtube/engine.rb", __dir__))
    api = File.read(File.expand_path("../lib/recording_studio_youtube/api.rb", __dir__))
    endpoints = File.read(File.expand_path("../lib/recording_studio_youtube/api/discovery.rb", __dir__))
    read = File.read(File.expand_path("../lib/recording_studio_youtube/api/read.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_youtube.api"'
    assert_includes engine, "RecordingStudio::YouTube::Api.register!"
    assert_includes api, "RecordingStudioApi.register_endpoint"
    assert_includes api, "return unless defined?(::RecordingStudioApi)"
    assert_includes api, "RecordingStudioApi.configuration.each_api"
    refute_includes api, "respond_to?"
    assert_includes endpoints, "youtube.search"
    assert_includes read, "access_grant.authorize!"
    assert_includes read, "AiTools.execute"
    assert_includes read, 'TOOL = "youtube_get_comment_replies"'
    refute_includes read, "AiTools.options"
    refute RecordingStudio::YouTube::AiTools.respond_to?(:options)
    assert RecordingStudio::YouTube::AiTools.respond_to?(:options, true)
    refute File.exist?(File.expand_path("../lib/recording_studio_youtube/mcp.rb", __dir__))
  end

  def test_search_registration_is_idempotent_per_api
    registrations = []
    registered = {}
    RecordingStudioApi.stub(:registered_endpoint, ->(name, api: :public) { registered[[api, name]] }) do
      RecordingStudioApi.stub(:register_endpoint, lambda { |name, **options|
        registrations << { name: name, **options }
        registered[[options.fetch(:api, :public), name]] = true
      }) do
        api_definition = Struct.new(:name).new(:public)
        configuration = Object.new
        configuration.define_singleton_method(:each_api) do |&block|
          block&.call(api_definition)
        end
        RecordingStudioApi.stub(:configuration, configuration) do
          2.times { RecordingStudio::YouTube::Api.register! }
        end
      end
    end

    names = registrations.map { |entry| entry.fetch(:name) }
    assert_equal 1, names.count(:"youtube.search")
    search = registrations.find { |entry| entry.fetch(:name) == :"youtube.search" }
    assert_equal :get, search.fetch(:http_verb)
    assert_equal "youtube/search", search.fetch(:path)
    assert_equal RecordingStudio::YouTube::Api::Search, search.fetch(:handler)
    assert_equal false, search.dig(:input_contract, :reject_unknown)
  end

  def test_search_handler_calls_the_existing_search_method
    captured = nil
    RecordingStudio::YouTube.stub(:search, lambda { |**options|
      captured = options
      page = Object.new
      def page.to_agent
        { "items" => [], "quota" => [{ "bucket" => "search_queries" }] }
      end
      page
    }) do
      payload = RecordingStudio::YouTube::Api::Search.call(
        FakeContext.new(params: { query: "zoo", type: "video" })
      )
      assert_equal "search_queries", payload.fetch("quota").first.fetch("bucket")
    end

    assert_equal "zoo", captured.fetch(:query)
    assert_equal "video", captured.fetch(:type)
  end

  def test_handlers_deny_unauthorized_callers
    error = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudio::YouTube::Api::Search.call(
        FakeContext.new(params: { query: "zoo" }, authorized: false)
      )
    end

    assert_match(/not authorized/, error.message)
  end

  def test_invalid_youtube_params_are_api_input_errors
    previous = RecordingStudio::YouTube.instance_variable_get(:@configuration)
    configuration = RecordingStudio::YouTube::Configuration.new
    configuration.api_key = "test-key"
    RecordingStudio::YouTube.instance_variable_set(:@configuration, configuration)

    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudio::YouTube::Api::Video.call(FakeContext.new(params: { id: "bad id" }))
    end

    assert_match(/invalid/, error.message)
  ensure
    RecordingStudio::YouTube.instance_variable_set(:@configuration, previous)
  end
end
