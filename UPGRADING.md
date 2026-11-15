# Upgrading RecordingStudio YouTube

## Upgrading to 0.6.0

`0.6.0` requires `recording_studio` `>= 7.0`, `< 8.0`. Update the host dependency to `recording_studio_youtube`, `~> 0.6.0`.

1. No migrations in this gem. Copy core migration `20261114090000_add_root_recording_id_to_recording_studio_events` when `recording_studio_events` has no `root_recording_id`.
2. Create roots with `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` only finds an existing root.
3. Set `config.authorize_write`. A present actor may write, including when `root_recording` is nil on a new root. Leave `allow_unauthorized_writes` unset.
4. Trashable `0.17` removed `recording_studio_trashable_kept_sql`. Use `Recording.kept`.
5. The dummy host pins core `v7.0.0`, Accessible `v0.44.0`, Admin `v2.16.0`, API `v0.24.0`, Trashable `v0.17.0`, Moveable `v5.0.0`, Metrics `v0.9.0`, Logs `v0.8.0`, Cache `v0.6.3`, Icons `v0.2.1`, Root Switchable `v0.16.0`, and FlatPack `v0.1.376`. Root Switchable `v0.11.5` requires core `< 7`. The dummy switcher lists roots the actor can view, and seeds grant owner access. Root Switchable 0.16 rejects the switch page without that grant.

If you are still on `0.5.0` or older, complete that release's notes first.

## Upgrading to 0.5.0

`0.5.0` registers public YouTube reads on Recording Studio API when that gem is loaded. Update the host dependency to `recording_studio_youtube`, `~> 0.5.0`.

1. No migrations in this gem.
2. Public YouTube read methods keep their current contracts. Search still spends the `search.list` Search Queries budget (100 calls a day) on the Ruby API and dummy HTML demo.
3. If the host mounts Recording Studio API, YouTube read endpoints appear on each named API after boot. There is no extra MCP registration. Search is not registered as an endpoint, so MCP does not advertise it.
4. Endpoint callers need Accessible `:view` on the request root.
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
