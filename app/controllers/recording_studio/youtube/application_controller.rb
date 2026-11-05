# frozen_string_literal: true

module RecordingStudio
  module YouTube
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception

      recording_studio_layout { RecordingStudio::YouTube.configuration.layout }
    end
  end
end
