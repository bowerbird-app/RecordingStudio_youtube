# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Diagnostics
      PROBE_VIDEO_ID = "jNQXAC9IVRw"

      def self.call(probe: false)
        configuration = RecordingStudio::YouTube.configuration
        lines = {
          "YouTube Data API key" => state(configuration.api_key_configured?),
          "Google OAuth client ID" => state(configuration.oauth_client_id_configured?)
        }
        lines["Public API access"] = probe ? probe_access : "not checked"
        lines
      end

      def self.state(configured)
        configured ? "configured" : "unavailable"
      end

      def self.probe_access
        RecordingStudio::YouTube.video(PROBE_VIDEO_ID)
        "working"
      rescue Error => e
        detail = e.reason.to_s.empty? ? e.class.name.split("::").last : "#{e.class.name.split('::').last} #{e.reason}"
        "failed (#{detail})"
      end

      private_class_method :state, :probe_access
    end
  end
end
