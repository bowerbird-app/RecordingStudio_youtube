# frozen_string_literal: true

require "time"
require_relative "urls"

module RecordingStudio
  module YouTube
    module Parsing
      module_function

      def time(value)
        return nil if value.nil? || value.to_s.strip.empty?

        Time.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def integer(value)
        return nil if value.nil? || value.to_s.strip.empty?

        Integer(value)
      rescue ArgumentError
        nil
      end

      def duration_seconds(iso)
        match = /\APT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?\z/.match(iso.to_s)
        return nil unless match
        return nil if match.captures.compact.empty?

        hours, minutes, seconds = match.captures.map(&:to_i)
        (hours * 3600) + (minutes * 60) + seconds
      end

      def dig(hash, *keys)
        return nil unless hash.is_a?(Hash)

        hash.dig(*keys)
      end
    end

    class Thumbnail
      attr_reader :variant, :url, :width, :height

      def initialize(variant:, url:, width:, height:)
        @variant = variant
        @url = url
        @width = width
        @height = height
      end

      def self.from_api(hash)
        return [] unless hash.is_a?(Hash)

        hash.filter_map do |variant, data|
          next unless data.is_a?(Hash)

          url = data["url"]
          next if url.to_s.empty?

          new(
            variant: variant.to_s,
            url: url,
            width: Parsing.integer(data["width"]),
            height: Parsing.integer(data["height"])
          )
        end
      end

      def to_h
        { "variant" => variant, "url" => url, "width" => width, "height" => height }
      end
    end

    class Thumbnails
      ORDER = %w[maxres standard high medium default].freeze

      def initialize(items)
        @items = Array(items).freeze
      end

      def self.from_api(hash)
        new(Thumbnail.from_api(hash))
      end

      attr_reader :items

      def [](variant)
        name = variant.to_s
        @items.find { |item| item.variant == name }
      end

      def primary
        ORDER.each do |variant|
          found = self[variant]
          return found if found
        end
        @items.first
      end

      def to_a
        @items.map(&:to_h)
      end
    end

    class Statistics
      attr_reader :raw

      def initialize(raw)
        @raw = raw.is_a?(Hash) ? raw : {}
      end

      def view_count
        Parsing.integer(@raw["viewCount"])
      end

      def like_count
        Parsing.integer(@raw["likeCount"])
      end

      def comment_count
        Parsing.integer(@raw["commentCount"])
      end

      def subscriber_count
        Parsing.integer(@raw["subscriberCount"])
      end

      def video_count
        Parsing.integer(@raw["videoCount"])
      end

      def hidden_subscriber_count
        value = @raw["hiddenSubscriberCount"]
        return nil if value.nil?

        value == true
      end

      def to_h
        {
          "view_count" => view_count,
          "like_count" => like_count,
          "comment_count" => comment_count,
          "subscriber_count" => subscriber_count,
          "video_count" => video_count,
          "hidden_subscriber_count" => hidden_subscriber_count
        }.compact
      end
    end

    class LiveStreamingDetails
      attr_reader :raw

      def initialize(raw)
        @raw = raw.is_a?(Hash) ? raw : nil
      end

      def actual_start_time
        Parsing.time(Parsing.dig(@raw, "actualStartTime"))
      end

      def actual_end_time
        Parsing.time(Parsing.dig(@raw, "actualEndTime"))
      end

      def scheduled_start_time
        Parsing.time(Parsing.dig(@raw, "scheduledStartTime"))
      end

      def scheduled_end_time
        Parsing.time(Parsing.dig(@raw, "scheduledEndTime"))
      end

      def concurrent_viewers
        Parsing.integer(Parsing.dig(@raw, "concurrentViewers"))
      end

      def active_live_chat_id
        Parsing.dig(@raw, "activeLiveChatId")
      end

      def to_h
        return nil if @raw.nil?

        {
          "actual_start_time" => actual_start_time&.iso8601,
          "actual_end_time" => actual_end_time&.iso8601,
          "scheduled_start_time" => scheduled_start_time&.iso8601,
          "scheduled_end_time" => scheduled_end_time&.iso8601,
          "concurrent_viewers" => concurrent_viewers,
          "active_live_chat_id" => active_live_chat_id
        }.compact
      end
    end

    class Video
      attr_reader :id, :title, :description, :channel_id, :channel_title, :published_at,
                  :thumbnails, :duration, :tags, :category_id, :statistics,
                  :live_streaming_details, :privacy_status, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        names = %i[
          title description channel_id channel_title published_at thumbnails duration tags
          category_id statistics live_streaming_details privacy_status raw
        ]
        names.each { |name| instance_variable_set(:"@#{name}", attributes[name]) }
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        new(snippet_attributes(item, snippet).merge(detail_attributes(item)))
      end

      def self.snippet_attributes(item, snippet)
        {
          id: item["id"],
          title: snippet["title"],
          description: snippet["description"],
          channel_id: snippet["channelId"],
          channel_title: snippet["channelTitle"],
          published_at: Parsing.time(snippet["publishedAt"]),
          thumbnails: Thumbnails.from_api(snippet["thumbnails"]),
          tags: snippet["tags"],
          category_id: snippet["categoryId"]
        }
      end

      def self.detail_attributes(item)
        content = item["contentDetails"] || {}
        status = item["status"] || {}
        {
          duration: content["duration"],
          statistics: Statistics.new(item["statistics"]),
          live_streaming_details: LiveStreamingDetails.new(item["liveStreamingDetails"]),
          privacy_status: status["privacyStatus"],
          raw: item
        }
      end
      private_class_method :snippet_attributes, :detail_attributes

      def url
        Urls.video(id)
      end

      def duration_seconds
        Parsing.duration_seconds(duration)
      end

      def to_agent
        identity_agent.merge(media_agent)
      end

      private

      def identity_agent
        {
          "id" => id,
          "title" => title,
          "description" => description,
          "channel_id" => channel_id,
          "channel_title" => channel_title,
          "published_at" => published_at&.iso8601,
          "url" => url,
          "privacy_status" => privacy_status
        }
      end

      def media_agent
        {
          "thumbnail" => thumbnails.primary&.to_h,
          "duration" => duration,
          "duration_seconds" => duration_seconds,
          "tags" => tags,
          "category_id" => category_id,
          "statistics" => statistics.to_h,
          "live_streaming_details" => live_streaming_details.to_h
        }
      end
    end

    class Channel
      attr_reader :id, :title, :description, :custom_url, :published_at, :thumbnails,
                  :statistics, :country, :uploads_playlist_id, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        @title = attributes[:title]
        @description = attributes[:description]
        @custom_url = attributes[:custom_url]
        @published_at = attributes[:published_at]
        @thumbnails = attributes[:thumbnails]
        @statistics = attributes[:statistics]
        @country = attributes[:country]
        @uploads_playlist_id = attributes[:uploads_playlist_id]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        new(
          id: item["id"],
          title: snippet["title"],
          description: snippet["description"],
          custom_url: snippet["customUrl"],
          published_at: Parsing.time(snippet["publishedAt"]),
          thumbnails: Thumbnails.from_api(snippet["thumbnails"]),
          statistics: Statistics.new(item["statistics"]),
          country: snippet["country"],
          uploads_playlist_id: Parsing.dig(item, "contentDetails", "relatedPlaylists", "uploads"),
          raw: item
        )
      end

      def url
        Urls.channel(id)
      end

      def handle_url
        Urls.handle(custom_url)
      end

      def to_agent
        {
          "id" => id,
          "title" => title,
          "description" => description,
          "custom_url" => custom_url,
          "published_at" => published_at&.iso8601,
          "url" => url,
          "handle_url" => handle_url,
          "country" => country,
          "uploads_playlist_id" => uploads_playlist_id,
          "thumbnail" => thumbnails.primary&.to_h,
          "statistics" => statistics.to_h
        }
      end
    end

    class Playlist
      attr_reader :id, :title, :description, :channel_id, :channel_title, :published_at,
                  :thumbnails, :item_count, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        @title = attributes[:title]
        @description = attributes[:description]
        @channel_id = attributes[:channel_id]
        @channel_title = attributes[:channel_title]
        @published_at = attributes[:published_at]
        @thumbnails = attributes[:thumbnails]
        @item_count = attributes[:item_count]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        new(
          id: item["id"],
          title: snippet["title"],
          description: snippet["description"],
          channel_id: snippet["channelId"],
          channel_title: snippet["channelTitle"],
          published_at: Parsing.time(snippet["publishedAt"]),
          thumbnails: Thumbnails.from_api(snippet["thumbnails"]),
          item_count: Parsing.integer(Parsing.dig(item, "contentDetails", "itemCount")),
          raw: item
        )
      end

      def url
        Urls.playlist(id)
      end

      def to_agent
        {
          "id" => id,
          "title" => title,
          "description" => description,
          "channel_id" => channel_id,
          "channel_title" => channel_title,
          "published_at" => published_at&.iso8601,
          "url" => url,
          "item_count" => item_count,
          "thumbnail" => thumbnails.primary&.to_h
        }
      end
    end

    class PlaylistItem
      attr_reader :id, :video_id, :title, :description, :position, :published_at,
                  :channel_id, :channel_title, :thumbnails, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        @video_id = attributes[:video_id]
        @title = attributes[:title]
        @description = attributes[:description]
        @position = attributes[:position]
        @published_at = attributes[:published_at]
        @channel_id = attributes[:channel_id]
        @channel_title = attributes[:channel_title]
        @thumbnails = attributes[:thumbnails]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        new(item_attributes(item, snippet))
      end

      def self.item_attributes(item, snippet)
        {
          id: item["id"],
          video_id: playlist_video_id(item, snippet),
          title: snippet["title"],
          description: snippet["description"],
          position: Parsing.integer(snippet["position"]),
          published_at: Parsing.time(snippet["publishedAt"]),
          channel_id: snippet["channelId"] || snippet["videoOwnerChannelId"],
          channel_title: snippet["channelTitle"] || snippet["videoOwnerChannelTitle"],
          thumbnails: Thumbnails.from_api(snippet["thumbnails"]),
          raw: item
        }
      end

      def self.playlist_video_id(item, snippet)
        Parsing.dig(item, "contentDetails", "videoId") || Parsing.dig(snippet, "resourceId", "videoId")
      end
      private_class_method :item_attributes, :playlist_video_id

      def url
        Urls.video(video_id)
      end

      def to_agent
        {
          "id" => id,
          "video_id" => video_id,
          "title" => title,
          "description" => description,
          "position" => position,
          "published_at" => published_at&.iso8601,
          "channel_id" => channel_id,
          "channel_title" => channel_title,
          "url" => url,
          "thumbnail" => thumbnails.primary&.to_h
        }
      end
    end

    class SearchItem
      attr_reader :kind, :video_id, :channel_id, :playlist_id, :title, :description,
                  :channel_title, :published_at, :thumbnails, :raw

      def initialize(attributes)
        @kind = attributes[:kind]
        @video_id = attributes[:video_id]
        @channel_id = attributes[:channel_id]
        @playlist_id = attributes[:playlist_id]
        @title = attributes[:title]
        @description = attributes[:description]
        @channel_title = attributes[:channel_title]
        @published_at = attributes[:published_at]
        @thumbnails = attributes[:thumbnails]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        id = item["id"] || {}
        new(
          kind: id["kind"],
          video_id: id["videoId"],
          channel_id: id["channelId"] || snippet["channelId"],
          playlist_id: id["playlistId"],
          title: snippet["title"],
          description: snippet["description"],
          channel_title: snippet["channelTitle"],
          published_at: Parsing.time(snippet["publishedAt"]),
          thumbnails: Thumbnails.from_api(snippet["thumbnails"]),
          raw: item
        )
      end

      RESOURCE_TYPES = {
        "youtube#video" => "video",
        "youtube#channel" => "channel",
        "youtube#playlist" => "playlist"
      }.freeze

      def resource_type
        RESOURCE_TYPES[kind]
      end

      def url
        case resource_type
        when "video" then Urls.video(video_id)
        when "channel" then Urls.channel(channel_id)
        when "playlist" then Urls.playlist(playlist_id)
        end
      end

      def to_agent
        {
          "resource_type" => resource_type,
          "video_id" => video_id,
          "channel_id" => channel_id,
          "playlist_id" => playlist_id,
          "title" => title,
          "description" => description,
          "channel_title" => channel_title,
          "published_at" => published_at&.iso8601,
          "url" => url,
          "thumbnail" => thumbnails.primary&.to_h
        }
      end
    end

    class Comment
      attr_reader :id, :text, :author_display_name, :author_channel_id, :like_count,
                  :published_at, :updated_at, :parent_id, :video_id, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        @text = attributes[:text]
        @author_display_name = attributes[:author_display_name]
        @author_channel_id = attributes[:author_channel_id]
        @like_count = attributes[:like_count]
        @published_at = attributes[:published_at]
        @updated_at = attributes[:updated_at]
        @parent_id = attributes[:parent_id]
        @video_id = attributes[:video_id]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        new(
          id: item["id"],
          text: snippet["textDisplay"] || snippet["textOriginal"],
          author_display_name: snippet["authorDisplayName"],
          author_channel_id: Parsing.dig(snippet, "authorChannelId", "value"),
          like_count: Parsing.integer(snippet["likeCount"]),
          published_at: Parsing.time(snippet["publishedAt"]),
          updated_at: Parsing.time(snippet["updatedAt"]),
          parent_id: snippet["parentId"],
          video_id: snippet["videoId"],
          raw: item
        )
      end

      def to_agent
        {
          "id" => id,
          "text" => text,
          "author_display_name" => author_display_name,
          "author_channel_id" => author_channel_id,
          "like_count" => like_count,
          "published_at" => published_at&.iso8601,
          "updated_at" => updated_at&.iso8601,
          "parent_id" => parent_id,
          "video_id" => video_id
        }
      end
    end

    class CommentThread
      attr_reader :id, :video_id, :top_level, :replies, :total_reply_count, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        @video_id = attributes[:video_id]
        @top_level = attributes[:top_level]
        @replies = attributes[:replies]
        @total_reply_count = attributes[:total_reply_count]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        top = snippet["topLevelComment"]
        reply_items = Parsing.dig(item, "replies", "comments") || []
        new(
          id: item["id"],
          video_id: snippet["videoId"],
          top_level: top ? Comment.from_api(top) : nil,
          replies: reply_items.map { |reply| Comment.from_api(reply) },
          total_reply_count: Parsing.integer(snippet["totalReplyCount"]),
          raw: item
        )
      end

      def to_agent
        {
          "id" => id,
          "video_id" => video_id,
          "total_reply_count" => total_reply_count,
          "top_level" => top_level&.to_agent,
          "replies" => replies.map(&:to_agent),
          "replies_complete" => !total_reply_count.nil? && replies.length == total_reply_count
        }
      end
    end

    class CaptionTrack
      attr_reader :id, :video_id, :language, :name, :track_kind, :audio_track_type, :draft, :raw

      def initialize(attributes)
        @id = attributes.fetch(:id)
        @video_id = attributes[:video_id]
        @language = attributes[:language]
        @name = attributes[:name]
        @track_kind = attributes[:track_kind]
        @audio_track_type = attributes[:audio_track_type]
        @draft = attributes[:draft]
        @raw = attributes[:raw]
      end

      def self.from_api(item)
        snippet = item["snippet"] || {}
        new(
          id: item["id"],
          video_id: snippet["videoId"],
          language: snippet["language"],
          name: snippet["name"],
          track_kind: snippet["trackKind"],
          audio_track_type: snippet["audioTrackType"],
          draft: snippet["isDraft"],
          raw: item
        )
      end

      def to_agent
        {
          "id" => id,
          "video_id" => video_id,
          "language" => language,
          "name" => name,
          "track_kind" => track_kind,
          "audio_track_type" => audio_track_type,
          "draft" => draft
        }
      end
    end

    class CaptionDownload
      attr_reader :id, :body, :content_type

      def initialize(id:, body:, content_type:)
        @id = id
        @body = body
        @content_type = content_type
      end
    end

    class Page
      attr_reader :items, :next_page_token, :previous_page_token, :total_results,
                  :results_per_page, :etag, :region_code, :raw, :quota, :requests

      COPIED = %i[total_results results_per_page etag region_code raw].freeze

      def initialize(attributes)
        @items = Array(attributes[:items]).freeze
        @next_page_token = blank_to_nil(attributes[:next_page_token])
        @previous_page_token = blank_to_nil(attributes[:previous_page_token])
        COPIED.each { |name| instance_variable_set(:"@#{name}", attributes[name]) }
        @quota = Array(attributes[:quota]).freeze
        @requests = attributes[:requests] || 1
      end

      def self.from_api(body, item_class:, quota:, requests: 1)
        page_info = body["pageInfo"] || {}
        new(
          items: Array(body["items"]).map { |item| item_class.from_api(item) },
          next_page_token: body["nextPageToken"],
          previous_page_token: body["prevPageToken"],
          total_results: page_info["totalResults"],
          results_per_page: page_info["resultsPerPage"],
          etag: body["etag"],
          region_code: body["regionCode"],
          raw: body,
          quota: quota,
          requests: requests
        )
      end

      def more?
        !next_page_token.nil?
      end

      def to_agent
        {
          "items" => items.map(&:to_agent),
          "next_page_token" => next_page_token,
          "previous_page_token" => previous_page_token,
          "more" => more?,
          "total_results" => total_results,
          "results_per_page" => results_per_page,
          "quota" => quota.map { |entry| quota_hash(entry) },
          "requests" => requests
        }
      end

      private

      def blank_to_nil(value)
        value.to_s.empty? ? nil : value
      end

      def quota_hash(entry)
        {
          "operation" => entry.operation,
          "units" => entry.units,
          "bucket" => entry.bucket,
          "daily_limit" => entry.daily_limit
        }
      end
    end

    class SearchResult < Page
      attr_reader :videos_by_id

      def initialize(attributes)
        super
        @videos_by_id = attributes[:videos_by_id]
      end

      def self.wrap(page, videos_by_id: nil, quota: nil, requests: nil)
        new(
          items: page.items,
          next_page_token: page.next_page_token,
          previous_page_token: page.previous_page_token,
          total_results: page.total_results,
          results_per_page: page.results_per_page,
          etag: page.etag,
          region_code: page.region_code,
          raw: page.raw,
          quota: quota || page.quota,
          requests: requests || page.requests,
          videos_by_id: videos_by_id
        )
      end

      def to_agent
        payload = super
        return payload if videos_by_id.nil?

        payload.merge(
          "videos" => videos_by_id.transform_values(&:to_agent)
        )
      end
    end

    class ChannelVideos < Page
      attr_reader :channel_id, :uploads_playlist_id

      def initialize(attributes)
        super
        @channel_id = attributes[:channel_id]
        @uploads_playlist_id = attributes[:uploads_playlist_id]
      end

      def self.wrap(page, channel)
        new(
          items: page.items,
          next_page_token: page.next_page_token,
          previous_page_token: page.previous_page_token,
          total_results: page.total_results,
          results_per_page: page.results_per_page,
          etag: page.etag,
          region_code: page.region_code,
          raw: page.raw,
          quota: [Quota.fetch("channels.list"), *page.quota],
          requests: page.requests + 1,
          channel_id: channel.id,
          uploads_playlist_id: channel.uploads_playlist_id
        )
      end

      def self.empty(channel, quota:)
        new(
          items: [],
          next_page_token: nil,
          previous_page_token: nil,
          total_results: 0,
          results_per_page: 0,
          etag: nil,
          region_code: nil,
          raw: nil,
          quota: quota,
          requests: 1,
          channel_id: channel.id,
          uploads_playlist_id: nil
        )
      end

      def to_agent
        super.merge(
          "channel_id" => channel_id,
          "uploads_playlist_id" => uploads_playlist_id
        )
      end
    end
  end
end
