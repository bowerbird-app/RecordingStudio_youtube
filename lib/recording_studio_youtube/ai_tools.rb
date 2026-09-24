# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module AiTools
      VERSION = 1
      SEARCH_FIELDS = %w[
        query type channel_id order published_after published_before language region
        video_duration safe_search max_results page_token
      ].freeze

      def self.register!
        return unless defined?(::RecordingStudioAI)

        definitions.each do |definition|
          ::RecordingStudioAI.tools.register(**definition, override: true)
        end
      end

      def self.definitions
        DISCOVERY + LIBRARY
      end

      def self.execute(name, arguments)
        executor = EXECUTORS[name]
        raise InvalidRequestError, "unknown YouTube tool: #{name}" unless executor

        executor.call(arguments)
      end

      def self.tool(key:, name:, description:, use_when:, do_not_use_when:, parameters:, returns:, cost:,
                    executor_label:, requires_confirmation: false)
        {
          key: key,
          version: VERSION,
          name: name,
          description: description,
          use_when: use_when,
          do_not_use_when: do_not_use_when,
          parameters: parameters,
          returns: returns,
          cost: cost,
          latency: :slow,
          read_only: true,
          destructive: false,
          requires_confirmation: requires_confirmation,
          idempotent: true,
          executor_label: executor_label,
          executor: ->(arguments, _context) { execute(key.to_s, arguments) }
        }
      end

      def self.param(name, type, required, description)
        { name: name, type: type, required: required, description: description }
      end

      EXECUTORS = {
        "youtube_search" => ->(arguments) { search(arguments).to_agent },
        "youtube_get_video" => ->(arguments) { video(arguments) },
        "youtube_get_channel" => ->(arguments) { channel(arguments).to_agent },
        "youtube_get_channel_videos" => ->(arguments) { channel_videos(arguments).to_agent },
        "youtube_get_playlist" => ->(arguments) { playlist(arguments) },
        "youtube_get_playlist_items" => ->(arguments) { playlist_items(arguments) },
        "youtube_get_comments" => ->(arguments) { comments(arguments).to_agent }
      }.freeze

      def self.video(arguments)
        RecordingStudio::YouTube.video(arguments.fetch("id")).to_agent
      end

      def self.playlist(arguments)
        RecordingStudio::YouTube.playlist(arguments.fetch("id")).to_agent
      end

      def self.search(arguments)
        RecordingStudio::YouTube.search(**options(arguments, SEARCH_FIELDS))
      end

      def self.channel(arguments)
        picked = options(arguments, %w[id handle])
        id = picked.delete(:id)
        raise InvalidRequestError, "id or handle is required" if id.nil? && picked[:handle].nil?

        RecordingStudio::YouTube.channel(id, **picked)
      end

      def self.channel_videos(arguments)
        names = %w[channel_id uploads_playlist_id max_results page_token]
        RecordingStudio::YouTube.channel_videos(**options(arguments, names))
      end

      def self.playlist_items(arguments)
        picked = options(arguments, %w[id max_results page_token])
        id = picked.delete(:id)
        RecordingStudio::YouTube.playlist_items(id, **picked)
      end

      def self.comments(arguments)
        names = %w[video_id max_results page_token order search_terms]
        RecordingStudio::YouTube.comments(**options(arguments, names))
      end

      def self.options(arguments, names)
        names.each_with_object({}) do |name, memo|
          key = argument_key(arguments, name)
          memo[name.to_sym] = arguments[key] unless key.nil?
        end
      end

      def self.argument_key(arguments, name)
        return name if arguments.key?(name)
        return name.to_sym if arguments.key?(name.to_sym)

        nil
      end

      private_class_method :tool, :param, :video, :playlist, :search, :channel, :channel_videos,
                           :playlist_items, :comments, :options, :argument_key
    end
  end
end

require_relative "ai_tools/discovery"
require_relative "ai_tools/library"
