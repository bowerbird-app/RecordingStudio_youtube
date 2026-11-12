# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module AiTools
      def self.authorize_tool!(context)
        grant = grant_from(context)
        if grant.respond_to?(:authorize!)
          grant.authorize!(recording: root_from(context), role: :view)
        elsif !accessible_view?(context)
          raise AuthorizationError, "YouTube is not authorized for this caller"
        end
      end

      def self.grant_from(context)
        context.access_grant if context.respond_to?(:access_grant)
      end

      def self.root_from(context)
        return context.root_recording if context.respond_to?(:root_recording)

        context.recording if context.respond_to?(:recording)
      end

      def self.actor_from(context)
        return context.initiator if context.respond_to?(:initiator)

        context.actor if context.respond_to?(:actor)
      end

      def self.accessible_view?(context)
        return false unless defined?(RecordingStudioAccessible)
        return false unless RecordingStudioAccessible.respond_to?(:authorized?)

        actor = actor_from(context)
        root = root_from(context)
        actor && root && RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :view)
      end
      private_class_method :authorize_tool!, :grant_from, :root_from, :actor_from, :accessible_view?
    end
  end
end
