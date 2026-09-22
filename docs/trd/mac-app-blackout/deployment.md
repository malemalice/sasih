# Deployment — mac-app-blackout (Sasih)

> Migrated from the former repo-root `TRD.md` §4, expanded with the actual scripts and versioning.

## 1. Distribution model

Free, direct distribution: a signed `.dmg` published as a GitHub Release asset (`Sasih.dmg`). No Mac App Store, ever (private-API usage). No auto-update framework — the app only *checks* for updates and opens the release page (see §4).

## 2. Build pipeline (scripts, no Xcode requirement)

This machine builds with Command Line Tools only (no full Xcode.app), so scripts pass extra search-path flags Xcode would normally provide.

| Script | What it does | Notes |
|---|---|---|
| `./test.sh` | `swift test` with CLT framework search-path flags | Run before every commit that touches `SasihCore` |
| `./build.sh` | `swift build -c release --product SasihApp`, then assembles `Sasih.app` (Info.plist, `AppIcon.icns`, menu bar PNGs, `PkgInfo`) | `--debug` for a debug build; `--sign` codesigns (`--force --deep --options runtime`) with `$SASIH_SIGNING_IDENTITY` (Developer ID Application). Fails loudly if `--sign` is passed without the env var. |
| `./dmg.sh` | Packages `Sasih.app` + `/Applications` symlink into `Sasih.dmg` (UDZO) via `hdiutil` | Run after `build.sh`. Does **not** notarize — deliberate manual step. |

`build.sh` refuses unknown flags and always rebuilds the bundle from scratch (`rm -rf Sasih.app` first). `Sasih.app` and `Sasih.dmg` are gitignored build outputs.

## 3. Versioning

- Source of truth: `Sources/SasihApp/Resources/Info.plist` → `CFBundleShortVersionString` (marketing) and `CFBundleVersion` (build number).
- A release is gated by bumping **both**, committing, then tagging `v<full-file-version>` (the `UpdateChecker` strips a leading `v` from `tag_name`, and `VersionComparison.isNewer` compares numerically — see `Tests/SasihCoreTests/VersionComparisonTests.swift`).
- Git history shows the established pattern: `Bump version to X.Y.Z` commit, e.g. `0.1.3` → `0.1.4`.

## 4. Signing & notarization

```bash
# 1. Build + sign
export SASIH_SIGNING_IDENTITY="Developer ID Application: ..."
./build.sh --sign
./dmg.sh

# 2. Notarize (manual — needs Apple ID app-specific password / API key)
xcrun notarytool submit Sasih.dmg --keychain-profile <profile> --wait
xcrun stapler staple Sasih.dmg

# 3. Publish
gh release create vX.Y.Z Sasih.dmg --title "vX.Y.Z" --notes "..."
```

Gatekeeper note for users (documented in README): unsigned/notarized-first-launch requires right-click → Open; notarized builds avoid this.

## 5. Update check contract

`UpdateChecker` calls `GET https://api.github.com/repos/malemalice/sasih/releases/latest` (unauthenticated, `Accept: application/vnd.github+json`) and compares `tag_name` (leading `v` stripped) against `CFBundleShortVersionString`. Consequences:

- The GitHub Release **must** use a semver-shaped tag (`v0.1.4`) or the comparison is wrong.
- The release must be a *full* release, not a draft/prerelease, to be returned as `latest`.
- `html_url` is what the "Download" button opens — assets are not fetched programmatically.
