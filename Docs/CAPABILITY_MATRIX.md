# Capability and validation matrix

Source version: **1.3.0**. This matrix separates implementation, automated checks, and live use. Build or fixture-render success does not establish sign-in, Premium eligibility, real playback, clean installation, or accessibility on every supported Mac.

## Environments

| Environment | Evidence and limit |
| --- | --- |
| Apple Silicon, macOS 27.0.1 | Existing 30-check harness passed on 2026-09-30 after repository extraction. Presentation/build validation is recorded in [VALIDATION.md](VALIDATION.md). |
| Apple Silicon, macOS 15.7.9 CI | [CI passed](https://github.com/heyaaakash/spotify-mac-menu/actions/runs/36713797814) all 30 mocked/native checks and app/ZIP packaging with Swift 6.1.2. No live Spotify session or installation test. |
| macOS 14 minimum | Declared in `Package.swift` and the app plist. No clean installation or real-user journey recorded here. |
| Intel Mac | On macOS 15.7.9, [CI passed](https://github.com/heyaaakash/spotify-mac-menu/actions/runs/36713797814) 29 checks and packaging. One native-render fixture is explicitly skipped because the hosted VM aborts in Metal. No physical Intel validation is recorded. |
| Other macOS releases | No complete version/device matrix recorded. |

## Features

All rows below describe implemented behavior unless marked unsupported. Live Spotify sign-in and playback are **unverified in this release-preparation record**.

| Feature | Automated evidence | Limits / live validation |
| --- | --- | --- |
| Compact and expanded players | Native size fixtures; 100 transition/dismissal sequences; appearance changes | Real popover animation and menu-bar interaction need live checks |
| Playback, seek, volume, shuffle, repeat | Mocked optimistic updates, command ordering, rollback, slider clamping | Needs Premium, an active Spotify device, and live playback checks |
| Liked songs, Undo | Current save/check endpoints, rapid heart changes, rollback, stale-check handling | Account permissions and live library changes need checking |
| Home and library | Paging/deduplication, snapshot restoration, preferences | Contents depend on Spotify app quota mode and access |
| Search | Debounce, cancellation, stale-result protection | Results and live account restrictions need checking; no search-result pagination |
| Queue / context continuation | Album/playlist offsets and ordered URI continuation | URI-list continuation contains the selected song plus at most 99 following loaded tracks |
| Device transfer | Mocked transfer progress and refresh | Real hardware availability, transfer, and restrictions need checking |
| PKCE and Keychain | Source reviewed; no live authorization test recorded | Browser denial, callback port conflict, token persistence, and reconnect need real-account testing |
| Desktop Spotify fallback | Disabled-fallback error path is tested | Real Automation allow/deny prompts and Apple Events need testing; basic controls only |
| Offline and rate limits | Mocked errors, retained metadata, suppressed repeated requests | Offline browsing does not provide offline Spotify playback |
| Settings and appearance | Persistence, Light/Dark/Auto, dynamic colors, contrast checks | Manual VoiceOver, keyboard-only journey, and performance testing remain open |
| Motion and artwork | Lifecycle gates, bounded equalizer levels, image downsampling | Equalizer is decorative and reflects playing state, not sampled audio |

## Unsupported

Windows, Linux, mobile app distribution, browser/VS Code extensions, local audio streaming, changing Spotify Autoplay, native Song Radio/recommendations, automatic app updates, Developer ID signing, and notarization are not provided by this release setup. Spotify audio still comes from the existing playback device.

## Recording new validation

Add the source version/commit, date, macOS version, architecture, Spotify app/account mode, method, result, and evidence. Distinguish mocked checks, native fixture rendering, CI, a clean installation, and external user reports. Remove or qualify public claims when Spotify API behavior changes.
