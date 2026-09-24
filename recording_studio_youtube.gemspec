# frozen_string_literal: true

require_relative "lib/recording_studio_youtube/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_youtube"
  spec.version     = RecordingStudio::YouTube::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_youtube"
  spec.summary     = "YouTube Data API for Recording Studio"
  spec.description = "Recording Studio's YouTube integration. It reads public YouTube data with an API key, " \
                     "describes user-authorized operations, and registers read-only tools for Recording Studio AI."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_youtube"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_youtube/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
