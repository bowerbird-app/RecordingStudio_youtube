# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudio::YouTube.instance_variable_get(:@configuration)
    RecordingStudio::YouTube.instance_variable_set(:@configuration, RecordingStudio::YouTube::Configuration.new)
  end

  def teardown
    RecordingStudio::YouTube.configuration.hooks.clear!
    RecordingStudio::YouTube.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudio::YouTube.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudio::YouTube.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_youtube.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_youtube.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudio::YouTube.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_youtube).new({ retries: 4 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { api_key: "from_yaml", timeout: 12 }
      end
    end.new(app_config)

    find_initializer("recording_studio_youtube.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudio::YouTube.configuration, hook_payload
    assert_equal "from_yaml", RecordingStudio::YouTube.configuration.api_key
    assert_equal 12, RecordingStudio::YouTube.configuration.timeout
    assert_equal 4, RecordingStudio::YouTube.configuration.retries
  end

  def test_load_config_treats_a_missing_yaml_file_as_absence
    pair_config = Class.new do
      def each_pair
        yield(:timeout, 15)
      end
    end.new

    xcfg = Struct.new(:recording_studio_youtube).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)

    app = Struct.new(:config) do
      def config_for(_name)
        raise "Could not load configuration. No such file - config/recording_studio_youtube.yml"
      end
    end.new(app_config)

    find_initializer("recording_studio_youtube.load_config").block.call(app)

    assert_equal 15, RecordingStudio::YouTube.configuration.timeout
  end

  def test_load_config_raises_when_rails_config_cannot_be_read
    bad_pair_config = Class.new do
      def each_pair
        raise "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_youtube).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { api_key: "ok" }
      end
    end.new(app_config)

    error = assert_raises(RuntimeError) do
      find_initializer("recording_studio_youtube.load_config").block.call(app)
    end

    assert_equal "bad pair", error.message
    assert_equal "ok", RecordingStudio::YouTube.configuration.api_key
  end

  def test_load_config_is_noop_without_config_sources
    RecordingStudio::YouTube.configuration.api_key = nil
    app = Struct.new(:config).new(Object.new)

    find_initializer("recording_studio_youtube.load_config").block.call(app)

    assert_nil RecordingStudio::YouTube.configuration.api_key
    assert_equal 5, RecordingStudio::YouTube.configuration.timeout
    assert_equal 0, RecordingStudio::YouTube.configuration.retries
  end

  def test_load_config_raises_when_yaml_cannot_be_merged
    yaml = Class.new do
      def each
        raise "bad yaml"
      end
    end.new

    xcfg = Struct.new(:recording_studio_youtube).new({ timeout: 22 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      attr_accessor :yaml

      def config_for(_name)
        @yaml
      end
    end.new(app_config)
    app.yaml = yaml

    error = assert_raises(RuntimeError) do
      find_initializer("recording_studio_youtube.load_config").block.call(app)
    end

    assert_equal "bad yaml", error.message
    assert_equal 5, RecordingStudio::YouTube.configuration.timeout
  end

  def test_engine_does_not_scan_models_or_controllers
    names = RecordingStudio::YouTube::Engine.initializers.map(&:name)

    refute_includes names, "recording_studio_youtube.apply_model_extensions"
    refute_includes names, "recording_studio_youtube.apply_controller_extensions"
    refute_respond_to RecordingStudio::YouTube::Engine, :apply_model_extensions
    refute_respond_to RecordingStudio::YouTube::Engine, :apply_controller_extensions
  end

  private

  def find_initializer(name)
    RecordingStudio::YouTube::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
