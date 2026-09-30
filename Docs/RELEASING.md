# Releasing SpotMenu

Current packaging is ad-hoc signed and not notarized. Developer ID signing/notarization and automatic updates are not configured. Keep the installation friction visible in README and release notes.

## Prepare and verify

1. Update `VERSION`, `BUILD_NUMBER`, `CHANGELOG.md`, and `Docs/RELEASE_NOTES.md`. For the first standalone release, the current source is 1.3.0, build 4; no version tag has been published.
2. Run `./Scripts/test.sh`, `./Scripts/package.sh`, and `./Scripts/screenshots.sh` as appropriate. Review images and package contents. Confirm the [Verify workflow](https://github.com/heyaaakash/spotify-mac-menu/actions/workflows/verify.yml) passes on both architecture jobs.
3. Record the exact commit and check [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md). Perform clean installation and live Spotify sign-in/playback on the environments you will claim. Exercise denied access, absent devices, disconnect, upgrade, and uninstall. Review licensing, icon rights, support access, and historical identities before a public launch.
4. Once that exact commit is approved, create and push an immutable `v` tag matching `VERSION`. Do not move an existing published tag.
5. Manually dispatch **Prepare draft release** with that tag. It tests/packages on both Mac architectures, verifies version/architecture, and creates a **draft** with two ZIPs and `SHA256SUMS.txt`. The workflow has no tag-triggered automatic public publication.
6. Review the draft, download every attached ZIP, check hashes, and install/open the downloads. Update public claims from those results, then make final publication an explicit owner action. Confirm the published page and support links while logged out.

There is no published binary release yet. Local package verification and passing CI do not replace steps 3 and 6.

## Credentials and signing

Verification uses read-only checkout permissions, pinned action commits, and no account credentials. The draft workflow grants `contents: write` only to its final job. Spotify tokens and Client IDs are never injected into CI. Keep signing certificates, private keys, and notary credentials outside Git in scoped protected secrets if Developer ID is later added.

For Developer ID distribution, add hardened runtime, required entitlements, secure timestamps, notarization, and stapling according to [Apple’s documentation](https://developer.apple.com/developer-id/). Test the actual downloaded result on a separate Mac before changing trust claims.

## Rollback and maintenance

There is no previous published standalone SpotMenu release yet. Keep the prior verified ZIP/checksum when a release exists. For a bad release, explain the issue in its notes, stop recommending that version, and publish a new immutable version from the corrected commit. Do not silently replace a published tag or assume newer local data can be read by an older binary.

The repository owner/maintainer is `heyaaakash`. Triage issues and CI failures after changes, review dependency/action updates monthly, and recheck Spotify API restrictions before each release. Update validation records and screenshots when behavior changes. Private security reports follow [SECURITY.md](../SECURITY.md).
