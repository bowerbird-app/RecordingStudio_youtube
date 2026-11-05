# Upgrading RecordingStudio YouTube

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
