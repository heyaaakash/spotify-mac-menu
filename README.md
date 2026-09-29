# SpotMenu

A native macOS menu bar companion for Spotify. It uses Spotify's Web API for search, library, queue, devices, and playback control. Audio plays on your existing Spotify device.

## Build and launch

Requires macOS 14 or later and the Swift command line tools or Xcode.

```sh
./Scripts/build-app.sh
open dist/SpotMenu.app
```

SpotMenu appears as a music note in the menu bar. It has a compact player and an expanded view with Home, Search, Library, and Queue. The player includes seek, volume, shuffle, repeat, device transfer, and a save button. Track menus offer play now, add to queue, and save.

## Connect Spotify

1. Create an app in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Add **`http://127.0.0.1:8888/callback`** to its redirect URIs.
3. Launch SpotMenu, paste the app's **Client ID**, and select **Connect Spotify**.
4. Approve the requested permissions in your browser. The browser returns to SpotMenu through a local callback on port 8888.

The app uses Authorization Code with PKCE. It stores the refresh token in macOS Keychain and the Client ID in user defaults. No client secret is used. Spotify may require Premium for playback controls, and at least one Spotify device must be available. A Spotify developer app may also be subject to Spotify's current development mode access limits.

When a playback API command fails, SpotMenu can send basic play, pause, skip, seek, and volume commands to the installed Spotify app through macOS Automation. macOS may prompt you to allow that access.

## Notes

- The app does not stream or download audio.
- The callback listener uses TCP port 8888. Close any other process using that port before connecting.
- Spotify controls and personal data require an account connection, so the interface cannot be fully exercised offline.
