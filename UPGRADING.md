# Upgrading RecordingStudio YouTube

## Upgrading to 0.5.0

`0.5.0` registers public YouTube reads on Recording Studio API when that gem is loaded. Update the host dependency to `recording_studio_youtube`, `~> 0.5.0`.

1. No migrations in this gem.
2. Public YouTube read methods keep their current contracts. Search still spends the `search.list` Search Queries budget (100 calls a day).
3. If the host mounts Recording Studio API, YouTube read endpoints appear on each named API after boot. There is no extra MCP registration.
4. Endpoint callers need Accessible `:view` on the request root. AI tools now make the same check before they spend the host YouTube key.
5. This gem does not depend on Recording Studio API at runtime. The dummy host pins API `v0.21.3`, Admin `v2.11.0`, Logs `v0.7.3`, Icons `v0.2.0`, Moveable `v4.1.0`, Redis `~> 5.3`, and FlatPack `v0.1.341` so the dummy can boot the API.

If you are still on `0.4.0` or older, complete that release's notes first.

## Upgrading to 0.4.0

`0.4.0` requires Recording Studio `>= 6.3.0`. Update the host dependency to
`recording_studio_youtube`, `~> 0.4.0`.

1. No migrations in this gem.
2. Public YouTube read methods keep their current contracts.
3. `RecordingStudio::YouTube.configuration.layout` defaults to
   `RecordingStudio::DEFAULT_LAYOUT` (`recording_studio/default_layout`).
   Assign a layout name, `false`, or a callable that accepts `controller:`.
   `RecordingStudio::Layout.accept` validates the value.
4. Call `recording_studio_layout` on engine and host controllers. Do not
   include `RecordingStudio::UsesDefaultLayout` and do not hard-code
   `layout "application"` or `layout "recording_studio/default_layout"`.
5. This repository's dummy host pins Recording Studio `v6.3.0`, FlatPack
   `v0.1.341`, Accessible `v0.24.1`, Trashable `v0.12.2`, Root Switchable
   `v0.11.5`, Metrics `v0.7.2`, and Cache `v0.6.2`. Match those tags if you
   want the dummy companion set.
6. Root Switchable `0.11+` accepts `nil`, `false`, a layout name String, or
   `call(controller:)`. The dummy no longer sets
   `config.layout = :application_layout`.
7. `FlatPack::Card::Component` no longer accepts `style:`.

If you are still on `0.3.7` or older, complete that release's notes first.
