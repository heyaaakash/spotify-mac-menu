# SpotMenu 1.3.0 — draft release notes

A native macOS menu bar companion for Spotify, with compact/full players, Home, Search, Library, Queue, saved-song Undo, device selection, cached browsing, and Light/Dark/Auto appearance.

## Downloads and installation

The draft-release workflow prepares `SpotMenu-1.3.0-macos-arm64.zip`, `SpotMenu-1.3.0-macos-x86_64.zip`, and `SHA256SUMS.txt` from an existing immutable tag. A local Apple Silicon package has been verified; this file does not assert that both downloads have been published or that a clean installation passed.

Check the ZIP’s SHA-256 against the release checksum file, unzip it, and move `SpotMenu.app` into Applications. Quit an older copy before replacing it. These builds are **ad-hoc signed and not notarized**. They are not Apple verified; downloaded app launches may be blocked by Gatekeeper. Use Apple’s [unknown-developer instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) only if you trust the download.

## Requirements and limitations

- Deployment target: macOS 14+. Actual environments checked are in the [capability matrix](CAPABILITY_MATRIX.md) and [validation record](VALIDATION.md).
- An eligible Spotify account, developer app Client ID, exact loopback redirect, and active Spotify device are required. Playback needs Premium; Spotify’s app quota mode can limit users and playlist contents.
- SpotMenu controls an existing playback device. It does not stream audio, generate Song Radio, change Spotify Autoplay, or update itself automatically.
- Live sign-in/playback, clean install, denied Automation access, upgrade/downgrade, minimum OS compatibility, VoiceOver, and physical Intel testing remain separate release checks.
- Screenshots are native interface previews with fictional sample data.

See [setup](SETUP.md), [privacy](PRIVACY.md), and [support issues](https://github.com/heyaaakash/spotify-mac-menu/issues/new/choose). Review the [changelog](../CHANGELOG.md) for current source changes.
