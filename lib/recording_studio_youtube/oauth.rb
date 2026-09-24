# frozen_string_literal: true

require "uri"

module RecordingStudio
  module YouTube
    module Oauth
      AUTHORIZATION_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
      TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

      READONLY = "https://www.googleapis.com/auth/youtube.readonly"
      MANAGE = "https://www.googleapis.com/auth/youtube"
      FORCE_SSL = "https://www.googleapis.com/auth/youtube.force-ssl"
      UPLOAD = "https://www.googleapis.com/auth/youtube.upload"
      PARTNER = "https://www.googleapis.com/auth/youtubepartner"

      def self.scopes_for(*capability_keys)
        keys = capability_keys.flatten
        raise InvalidRequestError, "at least one capability is required" if keys.empty?

        keys.flat_map { |key| Capabilities.fetch(key).scopes }.uniq
      end

      def self.authorization_url(redirect_uri:, state:, scopes: [READONLY], **options)
        client_id = configured_client_id(options[:client_id])
        validate_authorization_request!(client_id, redirect_uri, state)
        uri = URI(AUTHORIZATION_ENDPOINT)
        uri.query = URI.encode_www_form(authorization_query(client_id, redirect_uri, state, scopes, options))
        uri.to_s
      end

      def self.configured_client_id(client_id)
        return client_id unless client_id.to_s.strip.empty?

        RecordingStudio::YouTube.configuration.oauth_client_id
      end

      def self.validate_authorization_request!(client_id, redirect_uri, state)
        raise ConfigurationError, "Google OAuth client ID is not configured" if client_id.to_s.strip.empty?
        raise InvalidRequestError, "redirect_uri is required" if redirect_uri.to_s.strip.empty?
        raise InvalidRequestError, "state is required" if state.to_s.strip.empty?
      end

      def self.authorization_query(client_id, redirect_uri, state, scopes, options)
        params = {
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          scope: Array(scopes).join(" "),
          state: state,
          access_type: options.fetch(:access_type, "offline"),
          include_granted_scopes: options.fetch(:include_granted_scopes, true) ? "true" : "false"
        }
        params[:prompt] = options[:prompt] if options[:prompt]
        params
      end
      private_class_method :configured_client_id, :validate_authorization_request!, :authorization_query
    end
  end
end
