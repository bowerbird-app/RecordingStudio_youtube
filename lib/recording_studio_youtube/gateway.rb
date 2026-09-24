# frozen_string_literal: true

require "time"
require_relative "client"
require_relative "values"

module RecordingStudio
  module YouTube
    module ValueChecks
      ID_PATTERN = /\A[A-Za-z0-9_-]+\z/

      def one_of(value, allowed, name)
        text = value.to_s
        return text if allowed.include?(text)

        raise InvalidRequestError, "#{name} must be one of: #{allowed.join(', ')}"
      end

      def bounded(value, min, max, name)
        number = Integer(value)
        raise InvalidRequestError, "#{name} must be between #{min} and #{max}" unless number.between?(min, max)

        number
      rescue ArgumentError, TypeError
        raise InvalidRequestError, "#{name} must be an integer"
      end

      def timestamp(value)
        return value.utc.iso8601 if value.respond_to?(:utc)
        return value.to_time.utc.iso8601 if value.respond_to?(:to_time) && !value.is_a?(String)

        text = value.to_s
        Time.iso8601(text)
        text
      rescue ArgumentError
        raise InvalidRequestError, "timestamps must be RFC 3339"
      end

      def require_handle(value)
        text = value.to_s.strip.delete_prefix("@")
        return text if /\A[A-Za-z0-9._-]{3,30}\z/.match?(text)

        raise InvalidRequestError, "handle is invalid"
      end

      def require_id(value, name)
        text = value.to_s
        return text if ID_PATTERN.match?(text)

        raise InvalidRequestError, "#{name} is invalid"
      end

      def present?(value)
        !value.nil? && !value.to_s.strip.empty?
      end

      def channel_filters(id, handle, username, mine)
        filters = {}
        filters["id"] = require_id(id, "channel id") if present?(id)
        filters["forHandle"] = require_handle(handle) if present?(handle)
        filters["forUsername"] = username.to_s if present?(username)
        filters["mine"] = "true" if mine
        return filters if filters.length == 1

        raise InvalidRequestError, "specify exactly one of id, handle, username, or mine"
      end
    end

    module ParameterSupport
      include ValueChecks

      private :one_of, :bounded, :timestamp, :require_handle, :require_id, :present?, :channel_filters
      VIDEO_PARTS = "snippet,contentDetails,statistics,status,liveStreamingDetails"
      CHANNEL_PARTS = "snippet,contentDetails,statistics"
      PLAYLIST_PARTS = "snippet,contentDetails"
      PLAYLIST_ITEM_PARTS = "snippet,contentDetails"
      COMMENT_THREAD_PARTS = "snippet,replies"
      COMMENT_PARTS = "snippet"
      SEARCH_TYPES = %w[video channel playlist].freeze
      SEARCH_ORDERS = %w[date rating relevance title videoCount viewCount].freeze
      VIDEO_DURATIONS = %w[any short medium long].freeze
      EVENT_TYPES = %w[completed live upcoming].freeze
      SAFE_SEARCH = %w[moderate none strict].freeze
      LICENSES = %w[any creativeCommon youtube].freeze
      BLOCKED_PARAMS = %w[key access_token part].freeze
      FILTERS = [
        [:query, "q", :text],
        [:type, "type", :search_type],
        [:channel_id, "channelId", :channel_id],
        [:published_after, "publishedAfter", :time],
        [:published_before, "publishedBefore", :time],
        [:language, "relevanceLanguage", :text],
        [:region, "regionCode", :text],
        [:order, "order", :enum],
        [:video_duration, "videoDuration", :enum],
        [:event_type, "eventType", :enum],
        [:video_license, "videoLicense", :enum],
        [:safe_search, "safeSearch", :enum],
        [:page_token, "pageToken", :text]
      ].freeze
      ENUMS = {
        order: ["order", SEARCH_ORDERS],
        video_duration: ["video_duration", VIDEO_DURATIONS],
        event_type: ["event_type", EVENT_TYPES],
        video_license: ["video_license", LICENSES],
        safe_search: ["safe_search", SAFE_SEARCH]
      }.freeze

      private

      def search_params(options)
        require_search_target(options)
        params = base_search_params(options)
        FILTERS.each { |option, key, kind| copy_filter(params, key, kind, option, options[option]) }
        copy_embeddable(params, options[:embeddable])
        extra_params(options[:provider_params]).each { |key, value| params[key] = value }
        params
      end

      def require_search_target(options)
        return unless options[:query].to_s.strip.empty? && options[:channel_id].to_s.strip.empty?

        raise InvalidRequestError, "query or channel_id is required"
      end

      def base_search_params(options)
        {
          "part" => "snippet",
          "maxResults" => bounded(options.fetch(:max_results, 5), 0, 50, "max_results")
        }
      end

      def copy_filter(params, key, kind, option, value)
        return unless present?(value)

        params[key] = filter_value(kind, option, value)
      end

      def filter_value(kind, option, value)
        return value.to_s if kind == :text
        return search_type(value) if kind == :search_type
        return require_id(value, "channel id") if kind == :channel_id
        return timestamp(value) if kind == :time

        name, allowed = ENUMS.fetch(option)
        one_of(value, allowed, name)
      end

      def copy_embeddable(params, value)
        return if value.nil?

        params["videoEmbeddable"] = embeddable_value(value)
      end

      def extra_params(provider_params)
        return {} if provider_params.nil?
        raise InvalidRequestError, "provider_params must be a Hash" unless provider_params.is_a?(Hash)

        provider_params.each_with_object({}) do |(key, value), memo|
          name = key.to_s
          raise InvalidRequestError, "provider_params cannot set #{name}" if BLOCKED_PARAMS.include?(name)

          memo[name] = value.to_s
        end
      end

      def search_type(type)
        values = Array(type).map(&:to_s)
        unknown = values - SEARCH_TYPES
        raise InvalidRequestError, "type must be video, channel, or playlist" if unknown.any? || values.empty?

        values.join(",")
      end

      def embeddable_value(value)
        return "true" if value == true || value.to_s == "true"
        return "any" if value == false || value.to_s == "any"

        raise InvalidRequestError, "embeddable must be true or any"
      end
    end

    module ResourceReads
      include ParameterSupport

      def search(**options)
        enrich = options.delete(:enrich)
        body = @client.get("search", search_params(options), operation: "search.list")
        page = Page.from_api(body, item_class: SearchItem, quota: [Quota.fetch("search.list")])
        enriched(page, enrich)
      end

      def video(id)
        found = videos([id])
        return found.first unless found.empty?

        ErrorMapper.raise_empty("videos.list", "video")
      end

      def videos(ids)
        list = video_ids(ids)
        body = @client.get("videos", { "part" => VIDEO_PARTS, "id" => list.join(",") }, operation: "videos.list")
        Array(body["items"]).map { |item| Video.from_api(item) }
      end

      def channel(id = nil, handle: nil, username: nil, mine: false)
        filters = channel_filters(id, handle, username, mine).merge("part" => CHANNEL_PARTS)
        body = @client.get("channels", filters, operation: "channels.list")
        items = Array(body["items"]).map { |item| Channel.from_api(item) }
        return items.first unless items.empty?

        ErrorMapper.raise_empty("channels.list", "channel")
      end

      def channel_videos(channel_id:, page_token: nil, max_results: 5)
        found = channel(require_id(channel_id, "channel id"))
        if found.uploads_playlist_id.to_s.empty?
          return ChannelVideos.empty(found, quota: [Quota.fetch("channels.list")])
        end

        page = playlist_items(found.uploads_playlist_id, page_token: page_token, max_results: max_results)
        ChannelVideos.wrap(page, found)
      end

      private

      def enriched(page, enrich)
        return page if enrich.nil?
        raise InvalidRequestError, "enrich must be :videos" unless enrich.to_sym == :videos

        enrich_videos(page)
      end

      def enrich_videos(page)
        ids = page.items.filter_map(&:video_id).uniq
        return SearchResult.wrap(page) if ids.empty?

        found = videos(ids)
        SearchResult.wrap(
          page,
          videos_by_id: found.to_h { |item| [item.id, item] },
          quota: [Quota.fetch("search.list"), Quota.fetch("videos.list")],
          requests: 2
        )
      end

      def video_ids(ids)
        list = Array(ids).map { |id| require_id(id, "video id") }
        raise InvalidRequestError, "at least one video id is required" if list.empty?
        raise InvalidRequestError, "videos accepts at most 50 ids per request" if list.length > 50

        list
      end
    end

    module CollectionReads
      include ParameterSupport

      def playlist(id)
        body = @client.get(
          "playlists",
          { "part" => PLAYLIST_PARTS, "id" => require_id(id, "playlist id") },
          operation: "playlists.list"
        )
        items = Array(body["items"]).map { |item| Playlist.from_api(item) }
        return items.first unless items.empty?

        ErrorMapper.raise_empty("playlists.list", "playlist")
      end

      def playlist_items(id, page_token: nil, max_results: 5)
        params = {
          "part" => PLAYLIST_ITEM_PARTS,
          "playlistId" => require_id(id, "playlist id"),
          "maxResults" => bounded(max_results, 0, 50, "max_results")
        }
        params["pageToken"] = page_token if present?(page_token)
        body = @client.get("playlistItems", params, operation: "playlistItems.list")
        Page.from_api(body, item_class: PlaylistItem, quota: [Quota.fetch("playlistItems.list")])
      end

      def comments(video_id:, page_token: nil, max_results: 20, order: nil, search_terms: nil)
        params = comment_params(video_id, page_token, max_results, order, search_terms)
        body = @client.get("commentThreads", params, operation: "commentThreads.list")
        Page.from_api(body, item_class: CommentThread, quota: [Quota.fetch("commentThreads.list")])
      end

      def comment_replies(parent_id:, page_token: nil, max_results: 20)
        params = {
          "part" => COMMENT_PARTS,
          "parentId" => require_id(parent_id, "comment id"),
          "maxResults" => bounded(max_results, 1, 100, "max_results"),
          "textFormat" => "plainText"
        }
        params["pageToken"] = page_token if present?(page_token)
        body = @client.get("comments", params, operation: "comments.list")
        Page.from_api(body, item_class: Comment, quota: [Quota.fetch("comments.list")])
      end

      def caption_tracks(video_id:)
        body = @client.get(
          "captions",
          { "part" => "snippet", "videoId" => require_id(video_id, "video id") },
          operation: "captions.list"
        )
        Page.from_api(body, item_class: CaptionTrack, quota: [Quota.fetch("captions.list")])
      end

      def download_caption(id, format: nil, language: nil)
        track_id = require_id(id, "caption track id")
        params = {}
        params["tfmt"] = format.to_s if present?(format)
        params["tlang"] = language.to_s if present?(language)
        payload = @client.get_text("captions/#{track_id}", params, operation: "captions.download")
        CaptionDownload.new(id: track_id, body: payload["body"], content_type: payload["content_type"])
      end

      private

      def comment_params(video_id, page_token, max_results, order, search_terms)
        params = {
          "part" => COMMENT_THREAD_PARTS,
          "videoId" => require_id(video_id, "video id"),
          "maxResults" => bounded(max_results, 1, 100, "max_results"),
          "textFormat" => "plainText"
        }
        params["pageToken"] = page_token if present?(page_token)
        params["order"] = one_of(order, %w[time relevance], "order") if present?(order)
        params["searchTerms"] = search_terms.to_s if present?(search_terms)
        params
      end
    end

    class Gateway
      include ResourceReads
      include CollectionReads

      def initialize(authorization, configuration: RecordingStudio::YouTube.configuration)
        @client = Client.new(authorization, configuration: configuration)
      end
    end
  end
end
