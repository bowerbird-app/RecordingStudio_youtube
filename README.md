# RecordingStudio YouTube

`RecordingStudio::YouTube` is the YouTube integration for Recording Studio. A host application installs this gem, sets a YouTube Data API key, and can search and read public YouTube data. The gem does not store videos, channels, or playlists as Recording Studio records. Publications can map those objects into its own model later, without a change here.

The same client accepts a user access token for operations that Google requires a signed-in account to perform. This gem does not run the OAuth callback, store tokens, or attach a Google account to a Recording Studio user. Those jobs stay in the shared OAuth and user gems.

## Configure the gem

Set the key in code, or let the gem read it from the environment. `youtube_api_key` wins when both are set. `youtube` is the fallback.

```ruby
RecordingStudio::YouTube.configure do |config|
  config.api_key = ENV["youtube_api_key"]
  config.oauth_client_id = ENV["youtube_client_id"]
  config.timeout = 5
end
```

Calls to `ENV` live in `RecordingStudio::YouTube::Configuration`. Tests and hosts can assign `config.api_key` directly. The gem builds an authorization URL and does not exchange tokens, so it does not store a client secret.

`RecordingStudio::YouTube.diagnostics` reports whether a key and an OAuth client ID are configured. It does not print the values. Pass `probe: true` to read one known public video and report whether public API access is working.

## Read public data with an API key

Search, videos, channels, playlists, playlist items, and public comment threads accept an API key. The client sends the key as the `key` query parameter. It does not put the key in logs or in error messages.

```ruby
RecordingStudio::YouTube.video("jNQXAC9IVRw")
```

## Use Google OAuth when the call needs a user

Google OAuth 2.0 is required for the signed-in user's channel, caption tracks, caption downloads, and any future write. The default scope is `youtube.readonly`. Upload, partner, and full account scopes are available on the capabilities that need them. The gem does not request those scopes unless you ask for that capability.

`RecordingStudio::YouTube::Oauth.authorization_url` builds the Google authorization URL. You pass the redirect URI, the state value, and the scopes. The gem does not exchange the authorization code, refresh the token, or save it.

```ruby
url = RecordingStudio::YouTube::Oauth.authorization_url(
  redirect_uri: "https://app.example/callback",
  state: "state-from-your-oauth-layer",
  scopes: RecordingStudio::YouTube::Oauth.scopes_for(:get_mine_channel)
)
```

A Google account is not a YouTube channel. `channel(mine: true)` returns the YouTube channel for the authorized account.

## Search

Search returns light items. A search item is not a full video. Pass `enrich: :videos` when you want one extra `videos.list` call for the video ids on that page. The default does not do that, because search has its own daily limit.

```ruby
page = RecordingStudio::YouTube.search(
  query: "BowerBird architecture",
  type: :video,
  max_results: 5
)

page.items.first.title
page.next_page_token
page.more?
```

`type` accepts `video`, `channel`, `playlist`, or a list of those. Useful filters are `channel_id`, `published_after`, `published_before`, `language`, `region`, `order`, `video_duration`, `event_type`, `embeddable`, `video_license`, and `safe_search`. Pass anything else YouTube still accepts in `provider_params`. That hash cannot set `key`, `access_token`, or a field the gem already validates, including `q`, `part`, `maxResults`, and `pageToken`.

## Read a video

```ruby
video = RecordingStudio::YouTube.video("VIDEO_ID")
video.title
video.url
video.duration
video.thumbnails.primary
video.statistics.view_count
video.raw
```

`video.thumbnails` keeps the URL, width, height, and variant YouTube sent. `RecordingStudio::YouTube.videos(ids)` reads up to 50 ids in one call. A missing, private, or deleted id raises `RecordingStudio::YouTube::NotFoundError` from `video`. `videos` returns only the items YouTube included.

## Read a channel

Prefer a channel id. A handle works for lookup. A display name is not an id.

```ruby
channel = RecordingStudio::YouTube.channel("CHANNEL_ID")
channel = RecordingStudio::YouTube.channel(handle: "YouTube")
channel.uploads_playlist_id
channel.url
```

## Read a channel's videos

`channel_videos` reads the channel's uploads playlist, then one page of playlist items. It does not run a search. The first call is one `channels.list` plus one `playlistItems.list`. Pass `uploads_playlist_id` from that page on the next call to skip the channel lookup.

```ruby
page = RecordingStudio::YouTube.channel_videos(channel_id: channel.id, max_results: 5)
page.items.first.video_id
page = RecordingStudio::YouTube.channel_videos(
  uploads_playlist_id: page.uploads_playlist_id,
  page_token: page.next_page_token
)
```

## Read a playlist

```ruby
playlist = RecordingStudio::YouTube.playlist("PLAYLIST_ID")
items = RecordingStudio::YouTube.playlist_items(playlist.id, max_results: 5)
```

V1 does not create, update, or delete playlists.

## Read comments

`comments` reads comment threads for a public video. Each thread has a top-level comment, a reply count, and the replies YouTube included on that response. That reply list can be partial. `replies_complete` is false when the counts disagree. `comment_replies` reads the rest for one parent comment.

```ruby
threads = RecordingStudio::YouTube.comments(video_id: "VIDEO_ID", max_results: 20)
threads.items.first.top_level.text
threads.items.first.to_agent["replies_complete"]
```

Comments that the video owner has disabled raise `RecordingStudio::YouTube::AuthorizationError`.

## Read captions

The Data API does not return a public transcript for an arbitrary video with an API key.

`caption_tracks` lists tracks for a video the authorized user can edit. `download_caption` downloads one track for that same user. Both require OAuth scopes `youtube.force-ssl` or `youtubepartner`. There is no `transcript` method.

## Continue a page

List calls return one page. The caller decides whether to continue. Nothing in the gem walks every page, because each page spends quota.

```ruby
page = RecordingStudio::YouTube.search(query: "BowerBird", type: :video)
page = RecordingStudio::YouTube.search(
  query: "BowerBird",
  type: :video,
  page_token: page.next_page_token
) if page.more?
```

`next_page_token`, `previous_page_token`, and `more?` are on the page object. `to_agent` is the smaller hash for an agent. `raw` remains on the Ruby objects.

## Quota

Quota numbers come from Google's calculator as published on 2026-09-15. The standard daily budget is 10,000 units. `search.list` is not on that budget. It has a separate Search Queries budget of 100 calls a day, at 1 unit each. `videos.insert` has a separate budget of 100 calls a day. Most other list calls cost 1 unit. `captions.list` costs 50. The calculator does not list a unit cost for `captions.download`, so the gem leaves that cost nil.

`RecordingStudio::YouTube.capability(:search).quota` returns the operation, the unit cost, the budget name, and the daily limit. The gem does not invent a remaining-quota number. Google does not return one on these responses.

## Register AI tools

If `RecordingStudioAI` is loaded, the engine registers these read-only tools.

- `youtube_search`
- `youtube_get_video`
- `youtube_get_channel`
- `youtube_get_channel_videos`
- `youtube_get_playlist`
- `youtube_get_playlist_items`
- `youtube_get_comments`

Each tool sets `read_only` and a cost. Search is `high` and requires confirmation because of the 100-call daily budget. The other tools are `low` and do not require confirmation. Tool arguments accept string or symbol keys. Tool results use `to_agent` and omit `raw`.

`RecordingStudio::YouTube.capabilities` lists reads and the writes that are described but not implemented. A write capability has `implemented` false. Calling a write method on the module fails because the method is not defined.

## Call with a connected account

Pass an object that responds to `access_token`, or a hash with that key. A bare string is not a token.

```ruby
session = RecordingStudio::YouTube.for(connection)
session.channel(mine: true)
```

You can also pass `connection:` or `access_token:` on a single call. The client then sends a bearer token in the Authorization header and does not send the API key.

## Keep stored YouTube data fresh

YouTube API Services policies limit how long a client may store API data. Non-authorized API data is generally stored for at most 30 days, then deleted or refreshed. Authorized user data has its own refresh rules. Do not cache audiovisual content. This gem does not persist responses. A product that stores titles, statistics, or thumbnails has to apply those rules itself.

## Develop this gem

The dummy app under `test/dummy` is the host used by the engine tests. It pins RecordingStudio at v4.2.0, Accessible at v0.9.1, and FlatPack at v0.1.177. Sign in with `admin@admin.com` and password `Password` after `bin/rails db:setup` in that app.

```bash
bundle exec rake test
bundle exec rubocop
YOUTUBE_LIVE=1 bundle exec ruby -Itest test/live_youtube_test.rb
```

`rake test` does not call YouTube. The live file is one read-only pass over a known public video, its channel, one uploads page, one search, and one comment page. It does not upload or edit anything.
