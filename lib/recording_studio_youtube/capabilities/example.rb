# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Example
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:example, **)
      end
    end
  end
end

RecordingStudio.register_capability(
  :example,
  source: RecordingStudio::Capabilities::Example
)
