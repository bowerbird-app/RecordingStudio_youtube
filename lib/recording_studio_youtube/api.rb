# frozen_string_literal: true

require_relative "api/errors"
require_relative "api/fields"
require_relative "api/read"
require_relative "api/endpoints"

module RecordingStudio
  module YouTube
    module Api
      VIEW_ROLE = :view

      class << self
        def register!
          return unless defined?(::RecordingStudioApi)

          RecordingStudioApi.configuration.each_api { |api| register_on(api.name) }
        end

        def register_on(api)
          Endpoints::DEFINITIONS.each { |endpoint| register_endpoint!(endpoint, api: api) }
        end

        def register_endpoint!(endpoint, api:)
          name = endpoint.fetch(:name)
          return if RecordingStudioApi.registered_endpoint(name, api: api)

          RecordingStudioApi.register_endpoint(name, api: api, **endpoint.except(:name))
        end
        private :register_on, :register_endpoint!
      end
    end
  end
end
