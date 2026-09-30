# Screenshot previews

These PNGs show the actual SwiftUI/AppKit views rendered from the current source with **fictional sample data**. They are not photos of a live authenticated Spotify session. Sample covers are locally drawn abstract artwork, not copyrighted album covers.

```sh
./Scripts/screenshots.sh
```

The renderer uses an isolated user-defaults suite, a fixture token, a temporary library directory, and a URLSession protocol that intercepts API requests. It preloads the sample artwork into the app’s memory cache. It never reads Keychain, a real profile/library, or account credentials. Rendering may require macOS WindowServer/AppKit access.

Images cover Home and Compact in light/dark, plus Library, Search, Devices, Settings, and onboarding. Review regenerated images before committing; they do not certify VoiceOver, full keyboard navigation, animation smoothness, or real sign-in/playback.
