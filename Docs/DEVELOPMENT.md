# Development

SpotMenu uses Swift 6, SwiftUI, AppKit, Combine, CryptoKit, Network, and Security. It has no third-party Swift package dependencies.

```sh
./Scripts/test.sh          # Isolated regression checks
./Scripts/build-app.sh     # Release app bundle in dist/
./Scripts/package.sh       # Architecture-specific ZIP and checksum
./Scripts/screenshots.sh   # Native UI previews using sample data
```

Select a working Swift toolchain with `xcode-select`. The scripts honor `SDKROOT`. On this development machine, the macOS 27 command-line SDK lacks the SwiftUI macro plugin required by its interface, so scripts prefer the installed macOS 26.5 SDK when available. Other machines use `xcrun --show-sdk-path`. A full, compatible Xcode installation is recommended; selecting an SDK is not evidence that the app was tested on that OS.

`VERSION` supplies the app version. `BUILD_NUMBER` supplies the bundle build number. Settings reads the bundled version at runtime. Generated icons, compiler output, packaged apps, and temporary render files are excluded from Git.

The build queries SwiftPM for the binary directory rather than relying on a machine-specific output layout. Set `SPOTMENU_REGISTER_APP=0` in automated builds to skip refreshing Launch Services. App and ZIP verification checks the plist, signature, architecture, archive contents, and round-trip extraction. Signing is ad-hoc, without Developer ID or notarization.

## Source layout

| Path | Purpose |
| --- | --- |
| `Sources/SpotMenu/SpotMenuApp.swift` | App lifecycle, menu bar popovers, shortcuts, and appearance |
| `Sources/SpotMenu/SpotifyService.swift` | PKCE authorization, Web API requests, command ordering, recovery |
| `Sources/SpotMenu/AppState.swift` | Persisted preferences and optimistic player state |
| `Sources/SpotMenu/Infrastructure.swift` | Library/artwork caches, desktop Automation, responsiveness logs |
| `Sources/SpotMenu/ContentView.swift` | Onboarding and Home, Search, Library, and Queue |
| `Sources/SpotMenu/PlayerViews.swift` | Playback, seek, and volume controls |
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

Checks cover optimistic feedback during a delayed request, command ordering, rollback, rapid heart clicks, Undo, pagination, search cancellation, stale responses after disconnect, rate limits, offline recovery, transfer progress, preference/cache restoration, API decoding, artwork downsampling, collection context playback, and 100 repeated transition/dismissal sequences. Native SwiftUI/AppKit fixtures render Compact, Home, Library, Search, Devices, and Settings in both light and dark appearance to temporary PNGs for visual review. Checks also verify search playback context and offsets, ordered continuation, persisted settings, disabled search history and desktop fallback, Light/Dark overrides returning to Auto, dynamic appearance colors, live appearance notifications across both popovers without resizing, primary/accent text contrast, animation lifecycle gating, bounded waveform levels, and scrubber clamping.

The local feedback check enforces a 100 ms budget for the mocked control update. This does not measure Spotify's network latency or certify live menu animations; live authenticated behavior should also be exercised in the running app.

## Intel CI rendering limit

The hosted `macos-15-intel` VM aborts inside Metal (`Target device architecture is nil`) when the native SwiftUI snapshot fixture renders. Both workflows explicitly set `SPOTMENU_SKIP_UI_RENDER=1` for that VM. The harness reports the one skipped render check separately; all API/state, appearance, motion, slider, and other checks still execute, as does app/ZIP packaging. Apple Silicon CI and normal local runs keep all 30 checks enabled. Intel GUI rendering must be checked on a suitable Mac before claiming it validated.
