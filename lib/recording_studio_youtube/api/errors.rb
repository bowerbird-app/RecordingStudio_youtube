# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      module Errors
        module_function

        def raise_mapped!(error)
          raise map(error)
        end

        def map(error)
          klass = api_class_for(error)
          klass ? klass.new(error.message) : error
        end

        def api_class_for(error)
          return unless defined?(RecordingStudioApi)

          {
            InvalidRequestError => RecordingStudioApi::InvalidActionInputError,
            ConfigurationError => RecordingStudioApi::InvalidActionInputError,
            AuthenticationError => RecordingStudioApi::AuthenticationError,
            NotFoundError => RecordingStudioApi::NotFoundError,
            AuthorizationError => RecordingStudioApi::AuthorizationError,
            QuotaExceededError => RecordingStudioApi::AuthorizationError,
            RateLimitError => RecordingStudioApi::AuthorizationError
          }[error.class]
        end
      end
    end
  end
end
