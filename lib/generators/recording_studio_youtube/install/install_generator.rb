# frozen_string_literal: true

require "rails/generators"

module RecordingStudio
  module YouTube
    module Generators
      module TailwindSources
        private

        def show_missing_tailwind_notice
          say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
          say "If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow
          tailwind_source_lines.each { |entry| say "  #{entry.last}", :yellow }
        end

        def show_unresolved_source_notice
          say "Could not find RecordingStudio::YouTube views or FlatPack components to scan.", :yellow
        end

        def missing_tailwind_source_lines(tailwind_content)
          tailwind_source_lines.reject { |entry| tailwind_content.include?(entry.last) }
        end

        def inject_tailwind_sources(tailwind_css_path, missing_lines)
          inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
            "#{formatted_tailwind_source_block(missing_lines)}\n"
          end
          say "Added RecordingStudio::YouTube and FlatPack sources to Tailwind CSS configuration.", :green
          say "Run 'bin/rails tailwindcss:build' to rebuild your CSS.", :green
        end

        def formatted_tailwind_source_block(missing_lines)
          grouped = missing_lines.group_by(&:first)
          parts = []
          append_source_group(parts, grouped[:engine], "RecordingStudio::YouTube engine views")
          append_source_group(parts, grouped[:flatpack], "FlatPack component sources")
          parts.join("\n")
        end

        def append_source_group(parts, entries, label)
          return if entries.nil? || entries.empty?

          parts << "\n/* Include #{label} for Tailwind CSS */"
          entries.each { |entry| parts << entry.last }
        end

        def show_manual_tailwind_notice(missing_lines)
          say "Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow
          say "Please manually add these lines to your Tailwind CSS config:", :yellow
          missing_lines.each { |entry| say "  #{entry.last}", :yellow }
        end

        def tailwind_source_lines
          lines = []
          views = engine_views_directory
          lines << [:engine, source_directive(views)] if views
          components = flatpack_components_directory
          lines << [:flatpack, source_directive(components)] if components
          lines
        end

        def engine_views_directory
          path = RecordingStudio::YouTube::Engine.root.join("app/views")
          path.directory? ? path : nil
        end

        def flatpack_components_directory
          path = flatpack_components_path
          path if path&.directory?
        end

        def flatpack_components_path
          return FlatPack::Engine.root.join("app/components") if defined?(FlatPack::Engine)

          spec = Gem::Specification.find_by_name("flat_pack")
          Pathname.new(spec.gem_dir).join("app/components")
        rescue Gem::MissingSpecError
          bundled_flatpack_components
        end

        def bundled_flatpack_components
          pattern = File.join(Gem.dir, "bundler/gems/flatpack-*/app/components")
          found = Dir.glob(pattern).select { |dir| File.directory?(dir) }
          found.empty? ? nil : Pathname.new(found.min)
        end

        def source_directive(directory)
          css_dir = Rails.root.join("app/assets/tailwind")
          relative = Pathname.new(directory).expand_path.relative_path_from(css_dir.expand_path)
          %(@source "#{relative}";)
        end
      end

      class InstallGenerator < Rails::Generators::Base
        include TailwindSources

        source_root File.expand_path("templates", __dir__)

        desc "Installs RecordingStudio::YouTube engine into your application"

        class_option(
          :mount_path,
          type: :string,
          default: "/recording_studio_youtube",
          desc: "Route prefix used when mounting the engine"
        )

        def mount_engine
          route %(mount RecordingStudio::YouTube::Engine, at: "#{options[:mount_path]}")
        end

        def copy_initializer
          template "recording_studio_youtube_initializer.rb", "config/initializers/recording_studio_youtube.rb"
        end

        def add_yaml_config
          question = "Would you like to add `config/recording_studio_youtube.yml` " \
                     "for environment-specific settings? [y/N]"
          return unless yes?(question)

          template "recording_studio_youtube.yml", "config/recording_studio_youtube.yml"
        end

        def add_tailwind_source
          tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
          return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)
          return show_unresolved_source_notice if tailwind_source_lines.empty?

          tailwind_content = File.read(tailwind_css_path)
          missing_lines = missing_tailwind_source_lines(tailwind_content)

          if missing_lines.empty?
            say "Tailwind already configured to include RecordingStudio::YouTube and FlatPack sources.", :green
            return
          end

          if tailwind_content.include?('@import "tailwindcss"')
            inject_tailwind_sources(tailwind_css_path, missing_lines)
            return
          end

          show_manual_tailwind_notice(missing_lines)
        end

        def show_readme
          readme "INSTALL.md" if behavior == :invoke
        end
      end
    end
  end
end
