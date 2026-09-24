# frozen_string_literal: true

module RecordingStudio
  module YouTube
    # The controller directory is app/controllers/recording_studio/youtube.
    # Zeitwerk camelizes that segment. Without this acronym it expects Youtube.
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "YouTube"
    end

    module ConfigLoader
      MISSING_CONFIG = "Could not load configuration. No such file"

      def merge_recorded_config(app)
        merge_yaml(app)
        merge_rails_config(app)
      end

      private

      def merge_yaml(app)
        yaml = yaml_config(app)
        configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      def yaml_config(app)
        return nil unless app.respond_to?(:config_for)

        app.config_for(:recording_studio_youtube)
      rescue RuntimeError => e
        raise unless e.message.start_with?(MISSING_CONFIG)

        nil
      end

      def merge_rails_config(app)
        return unless rails_config?(app)

        hash = rails_config_hash(app.config.x.recording_studio_youtube)
        configuration.merge!(hash) if hash.respond_to?(:each)
      end

      def rails_config?(app)
        app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_youtube)
      end

      def rails_config_hash(value)
        return value.to_h if value.respond_to?(:to_h)
        return nil unless value.respond_to?(:each_pair)

        hash = {}
        value.each_pair { |key, entry| hash[key] = entry }
        hash
      end

      def configuration
        RecordingStudio::YouTube.configuration
      end
    end

    class Engine < ::Rails::Engine
      include ConfigLoader

      isolate_namespace RecordingStudio::YouTube

      initializer "recording_studio_youtube.before_initialize", before: "recording_studio_youtube.load_config" do |_app|
        RecordingStudio::YouTube.configuration.hooks.run(:before_initialize, self)
      end

      initializer "recording_studio_youtube.load_config" do |app|
        merge_recorded_config(app)
        RecordingStudio::YouTube.configuration.hooks.run(:on_configuration, RecordingStudio::YouTube.configuration)
      end

      initializer "recording_studio_youtube.after_initialize", after: "recording_studio_youtube.load_config" do |_app|
        RecordingStudio::YouTube.configuration.hooks.run(:after_initialize, self)
        RecordingStudio::YouTube::AiTools.register!
      end
    end
  end
end
