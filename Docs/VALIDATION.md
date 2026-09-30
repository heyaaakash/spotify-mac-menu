# Validation record

## 1.4.2 local release preparation — build 7

Verified on 2026-09-30 on Apple Silicon, macOS 27.0.1, Swift 6.4, using the installed macOS 26.5 SDK. GitHub Actions was disabled before the push; both workflow files were removed. Previous hosted results below are historical only.

- `./Scripts/prepare-release.sh` completed locally: **36 checks passed, 0 failures, 0 skipped**, nine native fictional-data screenshots regenerated and visually reviewed, both architecture packages built, and staged release checksums verified.
- arm64 was built for the host; x86_64 was cross-compiled with a macOS 14 deployment triple. Each ZIP was extracted and checked for matching architecture/version/build, valid ad-hoc signature, valid plist, identical executable, matching MIT license, an allowed file list, and SHA-256.
- The normal local `verify.sh` entry point runs tests and package verification. Its argument validation and refusal to skip native rendering were checked, along with invalid architecture rejection, release-preparation skip rejection, and draft upload rejection for an uncommitted tree.
- `dist/release-1.4.2/` contains both ZIPs, aggregate checksums, copied release notes, and build provenance. This preparation used a working tree based on `1c40823359ee3a69787e83b85ebb67ad579dbfd3`; provenance correctly records `source_state=dirty`. Rebuild from the final clean tagged commit before uploading a draft. No tag or release was created.

| Local package | Bytes | SHA-256 |
| --- | ---: | --- |
| `SpotMenu-1.4.2-macos-arm64.zip` | 2676990 | `e307f8b89b694aafaddb4918c85991baf2814fa2ec5bc027457f50af693b225d` |
| `SpotMenu-1.4.2-macos-x86_64.zip` | 2724040 | `ad61bbc39d809ff3d338f1dcd11819a815b7daa2c3e3c977cd3bcb5bfa8b2006` |

These are local review packages. Physical Intel runtime, live Spotify capture/permissions, minimum macOS installation, clean installation, and notarization remain unverified. Build success and synthetic/native fixtures establish only their specific checks.

## Earlier 1.4.2 working-source package — build 7

Date: **2026-09-30**, Asia/Kolkata. Same Apple Silicon/macOS/toolchain environment as the records below.

- `./Scripts/test.sh`: **36 passed, 0 failures, 0 skipped**. New assertions verify continuity when audio targets alternate rapidly, small per-frame wave changes across the clock-hour boundary, invalid target handling, and stopped-motion flattening.
- Native live/paused waveform fixtures rendered in both themes. The dark waveform layout was visually reviewed with fictional data and injected synthetic audio. These checks do not establish perceived smoothness during real Spotify playback or audio capture.
- `./Scripts/package.sh` rebuilt the Apple Silicon app/ZIP; version/build, plist, ad-hoc signature, SHA-256, archive allowlist, and round-trip executable equality passed. `git diff --check` passed.

| ZIP | Bytes | SHA-256 |
| --- | --- | --- |
| `SpotMenu-1.4.2-macos-arm64.zip` | 2676990 | `bcb31eb04db581f4a5b169bf8c61c74bbaa7e73237f730435cea59ea42695bfe` |

Working-source package only, without new CI, Intel build, published tag, clean installation, or live capture/permission validation. Capture remains capped at 30 frames per second; the small visible waveform draws at up to 60, with no real-capture CPU measurement claimed.

## 1.4.1 local working source — build 6

Date: **2026-09-30**, Asia/Kolkata. Same Apple Silicon/macOS/toolchain environment as the 1.4.0 record below.

- `./Scripts/test.sh`: **36 passed, 0 failures, 0 skipped**, including bounded measured/decorative waveform layers, stopped-motion flattening, existing seek controls, and fixed compact/expanded dimensions.
- Native fixtures rendered eight screens in both appearances, with synthetic live waveform and paused waveform states. Light/dark waveform layouts and the simplified Settings view were visually reviewed. Fictional songs/artwork and mock capture only; no actual audio tap or real Spotify account.
- The seek thumb now loads the current position immediately on menu presentation and track changes; preview position matched the elapsed-time label.
- `./Scripts/package.sh` rebuilt the Apple Silicon app/ZIP. Version/build, plist, ad-hoc signature, SHA-256, allowed bundle contents, and round-trip executable equality passed. `git diff --check` passed.

| ZIP | Bytes | SHA-256 |
| --- | --- | --- |
| `SpotMenu-1.4.1-macos-arm64.zip` | 2674833 | `67ea8f09e30ba7489fd6beec01ccd98a49d3ae667218f1bc5718fd105857eb07` |

Local working-source package only: no new CI, Intel build, published tag, clean installation, or live Spotify capture/permission validation. The app remains ad-hoc signed and not notarized.

## 1.4.0 local working source — build 5

Date: **2026-09-30**, Asia/Kolkata. These checks used the current working tree on Apple Silicon (`arm64`), macOS 27.0.1, Swift 6.4, and the installed macOS 26.5 SDK fallback.

| Check | Result and scope |
| --- | --- |
| Regression harness | `./Scripts/test.sh`: **36 passed, 0 failures, 0 skipped**. Synthetic PCM, mock capture/HTTP, isolated preferences/caches, and fixture token; no real Spotify requests, account, Keychain, or audio tap. |
| Capture recovery | Mocked cancellation, hidden/remote suspension, stale callback rejection, retained Settings errors, successful recovery, and opt-in persistence passed. |
| Native UI fixtures | Eight screens in both appearances: Compact, Home, Library, Search, Devices, Settings, live Spectrum, and live Waveform. Spectrum/waveform previews use synthetic measurements and fictional data. Both visualization layouts were visually reviewed. |
| Release package | `./Scripts/package.sh` rebuilt `dist/SpotMenu.app` and the Apple Silicon ZIP. Plist version/build/usage description, ad-hoc signature, SHA-256, archive file allowlist, and round-trip executable equality passed. |
| Source hygiene | `git diff --check` passed. |

| ZIP | Bytes | SHA-256 |
| --- | --- | --- |
| `SpotMenu-1.4.0-macos-arm64.zip` | 2691792 | `b454a75496197083714b4ef3396eff748786a108205e09daad8ff0e40f537697` |

This is a local working-source artifact, without a published tag, new CI run, or Intel 1.4.0 build. Live Spotify capture, audio permission allow/deny/retry, actual output devices, perceived beat alignment, and CPU measurements during real capture remain unverified. The new visualizer does not establish a BPM or musical beat grid. The package is ad-hoc signed and not notarized.

## 1.3.0 historical validation

Version: **1.3.0**, build **4**. Date: **2026-09-30**, Asia/Kolkata.

### Historical local checks

| Check | Result and scope |
| --- | --- |
| Environment | Apple Silicon (`arm64`), macOS 27.0.1, Apple Swift 6.4, installed macOS 26.5 SDK selected by the documented fallback |
| Source build | Fresh isolated clone of the extracted project, with this repository-preparation change applied; optimized release build passed |
| Regression harness | `./Scripts/test.sh`: **30 passed, 0 failures**; mock HTTP, isolated defaults/caches, fixture token |
| Native UI previews | `./Scripts/screenshots.sh`: nine Retina PNGs; actual SwiftUI/AppKit views, fictional data, locally drawn sample artwork |
| Package | `./Scripts/package.sh`: Apple Silicon ZIP produced; plist/version/build number, ad-hoc signature, SHA-256, extracted executable equality, and package file allowlist passed |
| Bundle contents | Executable, app icon, MIT license, plist, and signature metadata only |
| Repository checks | Shell syntax, YAML parsing, pinned action refs, whitespace, and relative documentation/image paths checked |

The local package is a working-source review artifact in `dist/`; it is not attached to a published release or tied to an immutable release tag. These historical packages were also built from committed source by the former hosted workflow.

### Historical CI — retired

The [Verify workflow](https://github.com/heyaaakash/spotify-mac-menu/actions/runs/36713797814) **passed both jobs** on macOS 15.7.9, Swift 6.1.2, from source commit `cbc9350fd15e98b278020b87a9df26002c248912`.

| Runner | Result |
| --- | --- |
| Apple Silicon (`macos-15`) | 30 checks passed, 0 failures, 0 skipped; app/ZIP packaging and upload passed |
| Intel (`macos-15-intel`) | 29 checks passed, 0 failures, 1 explicitly skipped native-render fixture; app/ZIP packaging and upload passed |

The [initial run](https://github.com/heyaaakash/spotify-mac-menu/actions/runs/36713483979) exposed a Metal assertion in the Intel VM during native snapshot rendering. That run reported one skipped check for the Intel hosted runner; the check executes in current local verification. This does not establish native rendering on physical Intel hardware. CI never uses a Spotify account or exercises live playback/permissions.

Both uploaded CI ZIPs were downloaded on 2026-09-30 and checked independently: SHA-256 matched, signatures and plists verified, bundle version was 1.3.0, architecture matched the filename, and the bundled license matched the repository license. They are local review artifacts in `dist/`, not a public release. GitHub CI artifacts have a 14-day retention policy.

| ZIP | Bytes | SHA-256 |
| --- | --- | --- |
| `SpotMenu-1.3.0-macos-arm64.zip` | 2609132 | `77033c3e7d27c2e71cb5134cd8d226cd7ebd1fa91287d91a1cc9c83bb3aed5be` |
| `SpotMenu-1.3.0-macos-x86_64.zip` | 2629951 | `b9a2892b8e37228c155c53660230f46639d543ceeb898f1555e5b64aeeaf57b8` |

## Remaining manual validation

Live browser authorization, real Spotify playback/library mutation, active-device transfers, actual allow/deny Automation prompts, clean downloaded-app installation, upgrade/downgrade, uninstall verification, physical Intel use, minimum macOS 14 use, VoiceOver, and complete keyboard-only use remain open. No Developer ID, notarization, auto-update, public download, or third-party user validation is claimed.

CI status, screenshots, and a local release build are evidence for their specific checks only. See [the capability matrix](CAPABILITY_MATRIX.md) before making broader support claims.
