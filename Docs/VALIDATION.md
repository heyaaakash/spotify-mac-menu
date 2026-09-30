# Validation record

Version: **1.3.0**, build **4**. Date: **2026-09-30**, Asia/Kolkata.

## Local checks

| Check | Result and scope |
| --- | --- |
| Environment | Apple Silicon (`arm64`), macOS 27.0.1, Apple Swift 6.4, installed macOS 26.5 SDK selected by the documented fallback |
| Source build | Fresh isolated clone of the extracted project, with this repository-preparation change applied; optimized release build passed |
| Regression harness | `./Scripts/test.sh`: **30 passed, 0 failures**; mock HTTP, isolated defaults/caches, fixture token |
| Native UI previews | `./Scripts/screenshots.sh`: nine Retina PNGs; actual SwiftUI/AppKit views, fictional data, locally drawn sample artwork |
| Package | `./Scripts/package.sh`: Apple Silicon ZIP produced; plist/version/build number, ad-hoc signature, SHA-256, extracted executable equality, and package file allowlist passed |
| Bundle contents | Executable, app icon, MIT license, plist, and signature metadata only |
| Repository checks | Shell syntax, YAML parsing, pinned action refs, whitespace, and relative documentation/image paths checked |

The local package is a working-source review artifact in `dist/`; it is not attached to a published release or tied to an immutable release tag. CI builds the committed source separately.

## CI

The [Verify workflow](https://github.com/heyaaakash/spotify-mac-menu/actions/workflows/verify.yml) targets Apple Silicon (`macos-15`) and Intel (`macos-15-intel`). Run results will be linked here after the workflow executes. It exercises mocked/native regression checks and app/ZIP packaging; it does not use a Spotify account or test live playback/permissions.

## Still unverified

Live browser authorization, real Spotify playback/library mutation, active-device transfers, actual allow/deny Automation prompts, clean downloaded-app installation, upgrade/downgrade, uninstall verification, physical Intel use, minimum macOS 14 use, VoiceOver, and complete keyboard-only use remain open. No Developer ID, notarization, auto-update, public download, or third-party user validation is claimed.

CI status, screenshots, and a local release build are evidence for their specific checks only. See [the capability matrix](CAPABILITY_MATRIX.md) before making broader support claims.
