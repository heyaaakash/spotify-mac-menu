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

The [Verify workflow](https://github.com/heyaaakash/spotify-mac-menu/actions/runs/36713797814) **passed both jobs** on macOS 15.7.9, Swift 6.1.2, from source commit `cbc9350fd15e98b278020b87a9df26002c248912`.

| Runner | Result |
| --- | --- |
| Apple Silicon (`macos-15`) | 30 checks passed, 0 failures, 0 skipped; app/ZIP packaging and upload passed |
| Intel (`macos-15-intel`) | 29 checks passed, 0 failures, 1 explicitly skipped native-render fixture; app/ZIP packaging and upload passed |

The [initial run](https://github.com/heyaaakash/spotify-mac-menu/actions/runs/36713483979) exposed a Metal assertion in the Intel VM during native snapshot rendering. That one check is now reported as skipped for the Intel hosted runner; it still executes locally and in Apple Silicon CI. This does not establish native rendering on physical Intel hardware. CI never uses a Spotify account or exercises live playback/permissions.

Both uploaded CI ZIPs were downloaded on 2026-09-30 and checked independently: SHA-256 matched, signatures and plists verified, bundle version was 1.3.0, architecture matched the filename, and the bundled license matched the repository license. They are local review artifacts in `dist/`, not a public release. GitHub CI artifacts have a 14-day retention policy.

| ZIP | Bytes | SHA-256 |
| --- | --- | --- |
| `SpotMenu-1.3.0-macos-arm64.zip` | 2609132 | `77033c3e7d27c2e71cb5134cd8d226cd7ebd1fa91287d91a1cc9c83bb3aed5be` |
| `SpotMenu-1.3.0-macos-x86_64.zip` | 2629951 | `b9a2892b8e37228c155c53660230f46639d543ceeb898f1555e5b64aeeaf57b8` |

## Still unverified

Live browser authorization, real Spotify playback/library mutation, active-device transfers, actual allow/deny Automation prompts, clean downloaded-app installation, upgrade/downgrade, uninstall verification, physical Intel use, minimum macOS 14 use, VoiceOver, and complete keyboard-only use remain open. No Developer ID, notarization, auto-update, public download, or third-party user validation is claimed.

CI status, screenshots, and a local release build are evidence for their specific checks only. See [the capability matrix](CAPABILITY_MATRIX.md) before making broader support claims.
