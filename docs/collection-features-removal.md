# Playlist and favorites removal

## Decision

Playlist and favorites functionality is removed from the mobile app. Existing
collection data is permanently deleted when local storage is opened after this
change.

## Scope

Removed:

- collection screens, track-detail actions, and their view models
- collection routes and public route helpers
- collection domain models and repository APIs
- the `favorites`, `playlists`, and `nextPlaylistId` JSON fields
- collection-specific localization strings and tests

Preserved:

- recent playback history
- cached track metadata used by Recent and deep links
- playback and equalizer settings
- transactional file replacement, backup recovery, and write serialization

## Storage migration

The local JSON format is now schema version 2. Opening an older file loads the
preserved `recentTrackIds` and `trackCache` values, then atomically rewrites the
file without the removed collection fields. Audio settings remain in
`SharedPreferences` and are unaffected.

This migration is intentionally irreversible. Rolling back to a version that
still exposes collection features will not restore deleted collection data.

## Route compatibility

Legacy `/library` and `/library/playlist/:id` links redirect to the catalog for
one compatibility window. They do not expose collection functionality and can
be deleted after supported upgrades have passed through this release.

## Regression guards

- repository tests verify immediate legacy-field deletion and preservation of
  recent history, track cache, and audio settings
- widget tests verify that removed actions are absent from track details
- navigation tests preserve no-autoplay, latest-request-wins, and mini-player
  behavior
- the integration flow covers catalog playback, explicit detail playback, and
  the Recent view
