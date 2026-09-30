# Contributing

Issues and pull requests are welcome. Open an issue first for a new integration, major UI change, or change to Spotify authorization. Include the app version, macOS version, Mac architecture, Spotify developer-app quota mode, and the behavior you actually checked.

Run `./Scripts/test.sh` for code changes and `./Scripts/package.sh` when build/packaging changes. Use `./Scripts/screenshots.sh` after changes that affect the screenshots. The test and screenshot harnesses use isolated preferences, temporary caches, mocked HTTP, and fixture tokens; they must never touch a real account or Keychain.

Keep playback commands ordered and protect against stale requests after disconnect. Preserve optimistic feedback, rollback, compact/expanded geometry, accessibility labels, Reduce Motion, and Auto/Light/Dark behavior. Update the [capability matrix](Docs/CAPABILITY_MATRIX.md) when validation changes, and distinguish a passing mock from a real Spotify session.

Remove tokens, Client IDs, account details, private playlists, device names, and callback URLs from logs/screenshots before sharing. Do not commit generated builds, downloaded music/artwork, local configuration, or signing credentials. The maintainer decides which proposals merge.
