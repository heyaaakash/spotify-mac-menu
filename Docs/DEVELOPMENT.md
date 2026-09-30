# Development

SpotMenu uses Swift 6, SwiftUI, AppKit, Combine, CryptoKit, Network, and Security. It has no third-party Swift package dependencies.

```sh
./Scripts/test.sh          # Isolated regression checks
./Scripts/build-app.sh     # Release app bundle in dist/
./Scripts/package.sh       # Architecture-specific ZIP and checksum
./Scripts/screenshots.sh   # Native UI previews using sample data
./Scripts/verify.sh        # Regression checks and native package verification
./Scripts/prepare-release.sh # Checks, previews, both architecture ZIPs and release files
```

Select a working Swift toolchain with `xcode-select`. The scripts honor `SDKROOT`. On this development machine, the macOS 27 command-line SDK lacks the SwiftUI macro plugin required by its interface, so scripts prefer the installed macOS 26.5 SDK when available. Other machines use `xcrun --show-sdk-path`. A full, compatible Xcode installation is recommended; selecting an SDK is not evidence that the app was tested on that OS.

`VERSION` supplies the app version. `BUILD_NUMBER` supplies the bundle build number. Settings reads the bundled version at runtime. Generated icons, compiler output, packaged apps, and temporary render files are excluded from Git.

The build queries SwiftPM for the binary directory rather than relying on a machine-specific output layout. Set `SPOTMENU_REGISTER_APP=0` in automated builds to skip refreshing Launch Services. App and ZIP verification checks the plist, signature, architecture, archive contents, and round-trip extraction. Signing is ad-hoc, without Developer ID or notarization.

## Source layout

| Path | Purpose |
| --- | --- |
| `Sources/SpotMenu/SpotMenuApp.swift` | App lifecycle, menu bar popovers, shortcuts, and appearance |
| `Sources/SpotMenu/PlaybackMonitor.swift` | App-lifetime detection, bounded desktop event parsing, wake/network hints, and polling |
| `Sources/SpotMenu/SpotifyService.swift` | PKCE authorization, Web API requests, command ordering, recovery |
| `Sources/SpotMenu/AppState.swift` | Persisted preferences and optimistic player state |
| `Sources/SpotMenu/Infrastructure.swift` | Library/artwork caches, desktop Automation, responsiveness logs |
| `Sources/SpotMenu/ContentView.swift` | Onboarding and Home, Search, Library, and Queue |
| `Sources/SpotMenu/PlayerViews.swift` | Playback, seek, and volume controls |
| `AudioAnalysis.swift`, `SpotifyAudioCapture.swift`, `AudioVisualizer.swift`, `VisualizerViews.swift` | Spotify process tap, DSP, capture lifecycle, and visualization UI |
| `Sources/SpotMenu/SettingsView.swift` | Appearance, playback, privacy, and account settings |
| `Sources/SpotMenu/Components.swift`, `Motion.swift` | Shared native controls, colors, and motion |
| `Tests/SpotMenuTests/` | Isolated regressions and screenshot renderer |
| `Resources/` | Source app icon; derived icons are generated during builds |

## Continuous playback

With **Continue searched songs** enabled (the default), selecting a search result starts its album at that exact track using Spotify's documented [`context_uri` and `offset` fields](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback). Selecting a track inside an album or playlist keeps that collection and its selected position, including repeated tracks. Liked Songs and Queue retain up to 99 following loaded songs in order. Context and URI-list playback continue on the Spotify device even while SpotMenu is closed; no background timer tries to restart paused music. The desktop Automation fallback also keeps album/playlist context.

For Spotify's own recommendations after the collection, enable **Autoplay** in Spotify Settings on the playback device. [Spotify's Autoplay guide](https://support.spotify.com/us/article/autoplay/) explains where to find it. SpotMenu cannot read or change this setting through the public Web API. New/development apps cannot call the [Recommendations endpoint](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api), so SpotMenu leaves personalized recommendations to Spotify rather than claiming to generate native Song Radio. If a track has no album metadata or no following loaded songs, its selection can still contain only that track; continuation then depends on Spotify Autoplay.

## Regression checks

```sh
./Scripts/test.sh
```

The standalone Swift harness works with command line tools and does not require XCTest. It uses an isolated URLSession mock, temporary caches, isolated preferences, and a fixture token. It never sends requests to Spotify or changes real account credentials.

Checks cover optimistic feedback during a delayed request, command ordering, rollback, rapid heart clicks, Undo, pagination, search cancellation, stale responses after disconnect, rate limits, offline recovery, transfer progress, preference/cache restoration, API decoding, artwork downsampling, collection context playback, and 100 repeated transition/dismissal sequences. Native SwiftUI/AppKit fixtures render Compact, Home, Library, Search, Devices, Settings, live Waveform, and paused Waveform in both light and dark appearance to temporary PNGs for visual review. Checks also verify search playback context and offsets, ordered continuation, persisted settings, disabled search history and desktop fallback, Light/Dark overrides returning to Auto, dynamic appearance colors, live appearance notifications across both popovers without resizing, primary/accent text contrast, animation lifecycle gating, bounded waveform levels, and scrubber clamping.

Six audio checks cover synthetic PCM frequency/loudness, silence and invalid input, bass onset decay, opt-in and suspension, stale callbacks and capture errors, and preference persistence. Native live/paused waveform fixtures inject synthetic measurements through a mock capture; tests never create a real process tap or request audio permission. Capture errors remain visible in Settings during suspension and clear after successful recovery. The integrated seek waveform is bounded and flattens when motion stops. Regression checks also exercise rapidly alternating audio targets and clock-hour boundaries, bounding per-frame changes in the continuously interpolated wave surface.

The local feedback check enforces a 100 ms budget for the mocked control update. This does not measure Spotify's network latency or certify live menu animations; live authenticated behavior should also be exercised in the running app.

## Local verification and cross-compilation

GitHub Actions is disabled and no workflow files are maintained. Run `./Scripts/verify.sh` before pushing; add `--screenshots` when previews need refreshing. `./Scripts/prepare-release.sh` performs the checks and previews, then builds both architectures sequentially in separate SwiftPM scratch directories. ZIPs, aggregate checksums, copied release notes, and build provenance are staged in `dist/release-VERSION/`.

`SPOTMENU_ARCH=arm64 ./Scripts/package.sh` or `SPOTMENU_ARCH=x86_64 ./Scripts/package.sh` selects a target with a macOS 14 deployment triple. Without this variable, the host architecture is used. Cross-compilation verifies the target binary and packaging, but cannot establish runtime behavior on the other architecture. Run the harness and open the package on a physical Intel Mac before claiming Intel runtime validation.

The native snapshot fixture requires working macOS graphics. An explicitly requested `SPOTMENU_SKIP_UI_RENDER=1 ./Scripts/test.sh` can diagnose a graphics-limited host; the harness reports its skipped render separately. Release preparation refuses this setting and requires all local checks. Historical hosted-runner results remain in [VALIDATION.md](VALIDATION.md).

## Automatic playback detection

`PlaybackMonitor` starts at app launch and stops at termination; popover closure does not stop it. It observes Spotify’s `com.spotify.client.PlaybackStateChanged` broadcast, workspace wake and Spotify app lifecycle events, and network restoration. Opening the menu or reconnecting also wakes the same monitor. In-flight fetches are not cancelled by new hints: a burst queues one follow-up. Polling is backed by the Web API with two-second foreground and five/ten-second background intervals, plus bounded failure backoff and global Retry-After handling.

Validated desktop metadata changes the local player on receipt; it never overrides a known active phone/speaker or a pending playback command. Web API enrichment supplies artwork/device details. A three-second reconciliation grace period prevents stale/204 API responses from immediately undoing a desktop event. Broadcast delivery is best-effort and does not provide an instant-detection guarantee; backup polling covers absent or missed notifications, browser playback, and remote devices. Live latency still needs measurement on the installed Spotify version.

Playback refresh releases its request slot before an independent saved-status lookup. Dynamic API requests ignore the local response cache. Session revision checks prevent cancelled old requests from restoring state or errors after disconnect. Ten regressions use mocked HTTP, synthetic desktop events, and monitors with system observation disabled; no real account, distributed broadcasts, or permissions are involved.

References: [Apple distributed notification delivery](https://developer.apple.com/documentation/foundation/distributednotificationcenter), [workspace wake notification](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification), [Spotify playback state](https://developer.spotify.com/documentation/web-api/reference/get-information-about-the-users-current-playback), and [Spotify rate limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits). The desktop event payload is an unofficial interface; its field names/units were cross-checked against a [first-hand broadcast example](https://gist.github.com/loretoparisi/6092634d34e97a062029b078215b6bdc), and fallback polling is retained.
