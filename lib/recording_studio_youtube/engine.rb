# frozen_string_literal: true

module RecordingStudio
  module YouTube
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

      class << self
        def apply_model_extensions(target)
          apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
        end

        def apply_controller_extensions(target)
          apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
        end

        private

        def extensions_for(kind, names)
          hooks = RecordingStudio::YouTube.configuration.hooks
          Array(names).flat_map do |name|
            if kind == :model
              hooks.model_extensions_for(name)
            else
              hooks.controller_extensions_for(name)
            end
          end
        end

        def apply_extensions(target, extensions)
          return unless target

          applied = target.instance_variable_get(:@recording_studio_youtube_applied_extensions) || identity_hash

          extensions.flatten.compact.each do |extension|
            next if applied[extension]

            target.class_eval(&extension)
            applied[extension] = true
          end

          target.instance_variable_set(:@recording_studio_youtube_applied_extensions, applied)
        end

        def extension_keys_for(target)
          names = [target.name, target.name&.demodulize].compact.uniq
          names.map(&:to_sym)
        end

        def identity_hash
          {}.compare_by_identity
        end
      end

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

      initializer "recording_studio_youtube.apply_model_extensions" do
        config.to_prepare do
          next unless defined?(ActiveRecord::Base)

          ActiveRecord::Base.descendants.each do |model|
            next if model.abstract_class?

            RecordingStudio::YouTube::Engine.apply_model_extensions(model)
          end
        end
      end

      initializer "recording_studio_youtube.apply_controller_extensions" do
        config.to_prepare do
          next unless defined?(ActionController::Base)

          ActionController::Base.descendants.each do |controller|
            RecordingStudio::YouTube::Engine.apply_controller_extensions(controller)
          end
        end
      end
    end
  end
end
