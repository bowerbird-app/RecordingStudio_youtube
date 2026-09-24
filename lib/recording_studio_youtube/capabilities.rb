# frozen_string_literal: true

require_relative "oauth"
require_relative "quota"

module RecordingStudio
  module YouTube
    module Capabilities
      Capability = Data.define(
        :key,
        :operation,
        :access,
        :authentication,
        :scopes,
        :quota_operation,
        :restrictions,
        :implemented
      ) do
        def quota
          Quota.fetch(quota_operation)
        end

        def read?
          access == :read
        end

        def write?
          access == :write
        end
      end

      def self.fetch(key)
        TABLE.fetch(key.to_sym) do
          raise Error, "unknown YouTube capability: #{key}"
        end
      end

      def self.all
        TABLE.values
      end

      def self.implemented
        all.select(&:implemented)
      end

      READ = %i[api_key user].freeze
      USER = %i[user].freeze
      SSL = [Oauth::FORCE_SSL, Oauth::PARTNER].freeze

      def self.read(key, operation, restrictions = nil, authentication: READ, scopes: [])
        Capability.new(
          key: key,
          operation: operation,
          access: :read,
          authentication: authentication,
          scopes: scopes,
          quota_operation: operation,
          restrictions: restrictions,
          implemented: true
        )
      end

      def self.write(key, operation, scopes, restrictions)
        Capability.new(
          key: key,
          operation: operation,
          access: :write,
          authentication: USER,
          scopes: scopes,
          quota_operation: operation,
          restrictions: restrictions,
          implemented: false
        )
      end

      require_relative "capabilities/catalog"
      private_class_method :read, :write
    end
  end
end
