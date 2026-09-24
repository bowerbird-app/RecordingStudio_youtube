# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudio
  module YouTube
    module Generators
      class MigrationsGenerator < Rails::Generators::Base
        include ActiveRecord::Generators::Migration

        source_root File.expand_path("../../../..", __dir__)

        desc "Copy RecordingStudio::YouTube migrations to your application"

        class_option :skip_existing, type: :boolean, default: true,
                                     desc: "Skip migrations that already exist (based on name, ignoring timestamp)"

        def copy_migrations
          migrations_dir = File.join(self.class.source_root, "db", "migrate")

          unless File.directory?(migrations_dir)
            say "No migrations found in RecordingStudio::YouTube engine.", :yellow
            return
          end

          migration_files = Dir.glob(File.join(migrations_dir, "*.rb"))

          if migration_files.empty?
            say "No migrations found in RecordingStudio::YouTube engine.", :yellow
            return
          end

          say "Found #{migration_files.size} migration(s) to install:", :green

          now = Time.now.utc
          migration_files.each_with_index do |source_path, index|
            filename = File.basename(source_path)
            migration_name = filename.sub(/^\d+_/, "")

            if options[:skip_existing] && migration_exists?(migration_name)
              say "  skip  #{migration_name} (already exists)", :yellow
              next
            end

            destination_filename = "#{migration_version(index, now)}_#{migration_name}"
            destination_path = File.join("db/migrate", destination_filename)

            copy_file source_path, destination_path
            say "  create  #{destination_path}", :green
          end

          say "\nRun 'bin/rails db:migrate' to apply the migrations.", :green
        end

        private

        def migration_exists?(migration_name)
          Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
        end

        def migration_version(index, now)
          format("%d", now.strftime("%Y%m%d%H%M%S").to_i + index)
        end
      end
    end
  end
end
