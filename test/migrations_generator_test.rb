# frozen_string_literal: true

require "test_helper"
require "generators/recording_studio_youtube/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_versions_increase_inside_one_second
    generator = RecordingStudio::YouTube::Generators::MigrationsGenerator.new
    now = Time.utc(2026, 9, 24, 3, 12, 0)

    assert_equal "20260924031200", generator.send(:migration_version, 0, now)
    assert_equal "20260924031201", generator.send(:migration_version, 1, now)
  end
end
