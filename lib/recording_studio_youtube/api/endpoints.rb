# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      module Endpoints
        TAGS = ["YouTube"].freeze

        def self.openapi(summary, description, parameters)
          { summary: summary, description: description, tags: TAGS, parameters: parameters }
        end

        def self.query(name, description, required: false, type: "string", location: "query")
          Fields.query_parameter(name, description, required: required, type: type, location: location)
        end
      end
    end
  end
end

require_relative "discovery"
require_relative "library"

module RecordingStudio
  module YouTube
    module Api
      module Endpoints
        DEFINITIONS = (Discovery::DEFINITIONS + Library::DEFINITIONS).freeze
      end
    end
  end
end
