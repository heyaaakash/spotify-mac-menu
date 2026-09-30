# SpotMenu 1.4.2 — draft release notes

A native macOS menu bar companion for Spotify, with compact/full players, Home, Search, Library, Queue, saved-song Undo, device selection, cached browsing, Light/Dark/Auto appearance, and optional Spotify audio visualization.

## Downloads and installation

The local `./Scripts/prepare-release.sh` script prepares `SpotMenu-1.4.2-macos-arm64.zip`, `SpotMenu-1.4.2-macos-x86_64.zip`, and `SHA256SUMS.txt` in `dist/release-1.4.2/`. Both packages are built locally; the Intel binary is cross-compiled. Uploading a draft requires a clean committed tree and an existing pushed immutable version tag. No download is published yet, and clean installation remains unverified.

Check the ZIP’s SHA-256 against the release checksum file, unzip it, and move `SpotMenu.app` into Applications. Quit an older copy before replacing it. These builds are **ad-hoc signed and not notarized**. They are not Apple verified; downloaded app launches may be blocked by Gatekeeper. Use Apple’s [unknown-developer instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) only if you trust the download.

## Music visuals

The song’s seek rail carries three soft, filled waveform layers, clipped to elapsed playback. Broad crests travel continuously; smoothed audio loudness changes their height without reshaping each crest from raw samples. There is one design, with no separate visualizer panel, style picker, or intensity slider. Settings → Music visuals contains only **Audio-reactive waveform**, off by default. It requires macOS 14.2+, Spotify playing on this Mac, and macOS audio permission. Samples stay in memory and are never recorded or uploaded. When capture is unavailable, waves animate decoratively; paused/hidden playback and Reduce Motion flatten them. Bass onset pulses are a heuristic, not a BPM/beat-grid detector. Live capture and permission handling remain manual validation items.

## Requirements and limitations

- Deployment target: macOS 14+. Actual environments checked are in the [capability matrix](CAPABILITY_MATRIX.md) and [validation record](VALIDATION.md).
- An eligible Spotify account, developer app Client ID, exact loopback redirect, and active Spotify device are required. Playback needs Premium; Spotify’s app quota mode can limit users and playlist contents.
- SpotMenu controls an existing playback device. It does not stream audio, generate Song Radio, change Spotify Autoplay, or update itself automatically.
- Live sign-in/playback, clean install, denied Automation access, upgrade/downgrade, minimum OS compatibility, VoiceOver, and physical Intel testing remain separate release checks.
- Screenshots are native interface previews with fictional sample data.

See [setup](SETUP.md), [privacy](PRIVACY.md), and [support issues](https://github.com/heyaaakash/spotify-mac-menu/issues/new/choose). Review the [changelog](../CHANGELOG.md) for current source changes.
