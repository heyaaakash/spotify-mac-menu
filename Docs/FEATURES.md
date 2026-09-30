# Features and keyboard shortcuts

These features are implemented. Automated checks and live validation are recorded separately in the [capability matrix](CAPABILITY_MATRIX.md).

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
