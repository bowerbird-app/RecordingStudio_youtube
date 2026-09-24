# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudio::YouTube::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(api_key: "abc123", timeout: 9, retries: 4)

    assert_equal "abc123", @configuration.api_key
    assert_equal 9, @configuration.timeout
    assert_equal 4, @configuration.retries
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", timeout: 7)

    refute_respond_to @configuration, :unknown_key
    assert_equal 7, @configuration.timeout
  end

  def test_merge_with_non_enumerable_is_noop
    @configuration.api_key = "abc123"
    @configuration.timeout = 9
    @configuration.retries = 4

    @configuration.merge!(nil)

    assert_equal "abc123", @configuration.api_key
    assert_equal 9, @configuration.timeout
    assert_equal 4, @configuration.retries
  end

  def test_initialize_prefers_youtube_api_key_over_youtube
    previous_api_key = ENV.fetch("youtube_api_key", nil)
    previous_youtube = ENV.fetch("youtube", nil)
    ENV["youtube_api_key"] = "env-token"
    ENV["youtube"] = "fallback-token"

    configuration = RecordingStudio::YouTube::Configuration.new

    assert_equal "env-token", configuration.api_key
    assert_equal 1, configuration.retries
    assert_equal 5, configuration.timeout
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
    refute_includes configuration.inspect, "env-token"
    refute_includes configuration.to_h.values.map(&:to_s), "env-token"
  ensure
    ENV["youtube_api_key"] = previous_api_key
    ENV["youtube"] = previous_youtube
  end

  def test_initialize_uses_youtube_when_api_key_name_is_absent
    previous_api_key = ENV.fetch("youtube_api_key", nil)
    previous_youtube = ENV.fetch("youtube", nil)
    ENV.delete("youtube_api_key")
    ENV["youtube"] = "fallback-token"

    configuration = RecordingStudio::YouTube::Configuration.new

    assert_equal "fallback-token", configuration.api_key
  ensure
    ENV["youtube_api_key"] = previous_api_key
    ENV["youtube"] = previous_youtube
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("api_key" => "string-key", "timeout" => 12)

    assert_equal "string-key", @configuration.api_key
    assert_equal 12, @configuration.timeout
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudio::YouTube.configure

    assert_kind_of RecordingStudio::YouTube::Configuration, RecordingStudio::YouTube.configuration
  end
end
