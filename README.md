# SpotMenu

A native macOS menu bar companion for Spotify. Browse and control music without leaving your current app. Audio plays on your existing Spotify device.

## Build and launch

Requires macOS 14 or later and Swift command line tools or Xcode.

The app bundle uses an optimized Release build.

```sh
./Scripts/build-app.sh
open dist/SpotMenu.app
```

Quit an already running copy before opening a rebuilt app.

The build generates the macOS app icon from `spotmenu-icon.png`, including all standard and Retina sizes in `Resources/SpotMenu.iconset` and the bundled `Resources/SpotMenu.icns`. To regenerate only the icons, run `./Scripts/build-icon.sh`.

After signing, the build updates the app folder's modification date and refreshes its Launch Services registration so Finder notices changed icons in an existing `dist/SpotMenu.app`.

## The experience

- **Two player sizes:** a 432 × 140 compact player and a 432 × 690 expanded menu. Separate fixed hosting controllers and cancellable transition tokens prevent stale resize/reopen work from moving the content.
- **A persistent player:** playback, seek, volume, shuffle, repeat, hearts, and device selection stay above Home, Search, Library, and Queue.
- **Immediate controls:** playback and hearts update locally before a request finishes. Commands are sent in order; failures restore the affected control without erasing other changes. Saved-song changes include an Undo toast.
- **A populated launch:** playlists, liked songs, recent tracks, and top tracks load from a disk snapshot, then refresh concurrently. Album artwork uses a memory cache, a disk cache, coalesced downloads, and thumbnails sized for the display.
- **A fuller library:** pin favorite playlists to Home, filter playlists and liked songs, and load additional library and collection pages. Collection play buttons start the playlist or album context.
- **Search:** a 220 ms debounce, cancellation of stale results, type filters, eight recent searches, and keyboard selection.
- **Clear recovery:** cached content stays available when offline; expired sessions, unavailable devices, and rate limits get specific recovery actions. Device transfers show progress. Compact mode exposes an error indicator that opens the full recovery view.
- **Remembered preferences:** player size, selected tab, library filter, pins, browsing position, recent searches, and volume survive relaunches.
- **Appearance & settings:** choose Auto, Light, or Dark in the scrollable in-menu Settings panel. Auto follows macOS immediately. Persisted options control animations, continuation for individual song selections, desktop playback fallback, recent-search history, and the menu bar playing indicator. Reduce Motion is always respected. Settings has no separate window to open or restore at launch.
- **Motion:** spring presses and hover lift, bouncing SF Symbols, morphing play/pause, a sliding tab selection pill, collection transitions, sliding sheets, and spring toasts. The Now Playing artwork lifts when playing; five equalizer bars animate smoothly over a softly moving player glow.
- **Music controls:** iPhone-inspired scrubbers expand their track and thumb while interacting and move smoothly during playback. Drag changes stay local until release; keyboard and accessibility adjustments are supported.
- **Native details:** full-width rows, bounded playlist tiles, current-track states, and accessible control labels. Device lists scroll within the menu. Reduce Motion replaces springs with short fades and freezes decorative playback animations.

Playback polling and the progress timer run while the menu is open. Continuous visual animations stop when the menu is closed, their player mode is hidden, music is paused, or Reduce Motion is enabled. Player animations also stop behind Settings and Devices. Equalizer bars reflect playback state; Spotify does not expose audio samples for an actual audio meter. Artwork processing, cache I/O, JSON decoding, and local Spotify Automation run away from the UI thread. Popover presentation timing is recorded through OSLog under subsystem `com.spotmenu.app`, category `Responsiveness`.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘⇧Space | Open or close SpotMenu globally |
| ⌘K | Expand and focus Search |
| ⌘, | Open Settings in the expanded menu |
| ↑ / ↓ | Select a search result |
| Return | Play a song or open a collection |
| Space | Play/pause when not typing |
| Escape | Close an overlay, return from a collection, or dismiss the menu |

If another app has claimed ⌘⇧Space, SpotMenu reports that the shortcut is unavailable.

## Connect Spotify

1. Create an app in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Add **`http://127.0.0.1:8888/callback`** to its redirect URIs.
3. Launch SpotMenu, paste the app's **Client ID**, and select **Connect Spotify**.
4. Approve the requested permissions in your browser, then return to SpotMenu.

Authorization uses PKCE. The refresh token is stored in macOS Keychain; the Client ID and preferences use user defaults. Cached library metadata is stored in `~/Library/Application Support/SpotMenu`; artwork is stored in `~/Library/Caches/SpotMenu/Artwork`. Disconnecting removes the library snapshot and token. Artwork caches are bounded to roughly 50 MB on disk and 30 MB in memory.

Spotify may require Premium for playback controls. Its development mode also limits eligible accounts and playlist content access. SpotMenu uses the current [`/me/library` save endpoint](https://developer.spotify.com/documentation/web-api/reference/save-library-items) and [`/me/library/contains` endpoint](https://developer.spotify.com/documentation/web-api/reference/check-library-contains). The [February 2026 migration guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide) describes current development mode restrictions. Collections that Spotify does not expose can be opened in Spotify.

When enabled in Settings and a basic playback command fails, SpotMenu can send play, pause, skip, seek, and volume commands to the installed Spotify app through macOS Automation. macOS may prompt for access. These commands have an eight-second timeout.

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
