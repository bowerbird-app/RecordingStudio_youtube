# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_youtube.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v7.7.1"

# flat_pack is not published to RubyGems.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.378"

gem "devise"
gem "puma", "8.1.0"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.54.0"
  gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.19.0"
  gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v1.15.0"
  gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.4.1"
  gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.8.1"
  gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.9.1"
  gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.0.1"
  gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.2.0"
  gem "redis", "~> 5.3"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
