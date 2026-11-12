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
          return unless available?

          apis.each { |api| register_on(api) }
          true
        end

        def available?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:register_endpoint) &&
            RecordingStudioApi.respond_to?(:registered_endpoint)
        end

        def apis
          return [:public] unless configuration_each_api?

          RecordingStudioApi.configuration.each_api.map(&:name)
        end

        def register_on(api)
          Endpoints::DEFINITIONS.each { |endpoint| register_endpoint!(endpoint, api: api) }
        end

        def register_endpoint!(endpoint, api:)
          name = endpoint.fetch(:name)
          return if RecordingStudioApi.registered_endpoint(name, api: api)

          RecordingStudioApi.register_endpoint(name, api: api, **endpoint.except(:name))
        end

        def configuration_each_api?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:configuration) &&
            RecordingStudioApi.configuration.respond_to?(:each_api)
        end
        private :register_on, :register_endpoint!, :configuration_each_api?
      end
    end
  end
end
