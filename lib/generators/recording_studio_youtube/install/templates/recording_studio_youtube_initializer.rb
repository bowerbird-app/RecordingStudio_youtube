# frozen_string_literal: true

RecordingStudio::YouTube.configure do |config|
  config.api_key = ENV["youtube_api_key"] if ENV["youtube_api_key"]
end
