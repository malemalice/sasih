# Playbook — Release

Only the Release Engineer runs this, and only with **explicit owner approval** (hard rule 5). No approval, no release.

## Pre-flight (all must be true before building)

1. **Owner approval** — explicit "yes, publish", not inferred.
2. **Tests** — `./test.sh` green on the exact commit being shipped.
3. **Hardware matrix** — completed on the current build (`docs/playbooks/hardware-verification.md`), including the recovery-path confirmation. No matrix results → stop.
4. **Docs current** — `docs/trd/mac-app-blackout/deployment.md`, `docs/api-contracts/changes.md`, and any changed doc are up to date.
5. **Working tree clean** at the release commit (no uncommitted build-affecting changes).

## Version bump

1. Edit `Sources/SasihApp/Resources/Info.plist`:
   - `CFBundleShortVersionString` → `X.Y.Z`
   - `CFBundleVersion` → increment by 1
2. Commit with the established convention: `Bump version to X.Y.Z`.

## Build, package, sign, notarize

```bash
export SASIH_SIGNING_IDENTITY="Developer ID Application: <name> (<TEAMID>)"

./build.sh --sign            # release build + codesign --force --deep --options runtime
./dmg.sh                     # packages Sasih.dmg (unsigned DMG containing signed app)

xcrun notarytool submit Sasih.dmg --keychain-profile <profile> --wait
xcrun stapler staple Sasih.dmg
```

Verify before publishing:

```bash
codesign --verify --deep --strict --verbose=2 Sasih.app
stapler validate Sasih.dmg
spctl --assess --type open --context context:primary-signature -v Sasih.dmg
```

Do **not** rebuild `Sasih.app` after notarization — staple the exact artifact you submitted.

## Publish

```bash
gh release create vX.Y.Z Sasih.dmg \
  --title "vX.Y.Z" \
  --notes "<user-facing summary: what changed, in plain language>"
```

- Tag must be `vX.Y.Z` (semver-shaped; `UpdateChecker` strips the `v`).
- Publish as a **full release** — drafts/prereleases are invisible to `releases/latest`.
- Never retag or replace an already-published release; ship a fixed patch version instead.

## Post-flight

1. Confirm the update contract:
   ```bash
   curl -s -H 'Accept: application/vnd.github+json' \
     https://api.github.com/repos/malemalice/sasih/releases/latest | \
     python3 -c 'import json,sys; r=json.load(sys.stdin); print(r["tag_name"], r["html_url"])'
   ```
   Expected: `vX.Y.Z` and the release URL.
2. Run the app's **Check for Updates…** from an older build if available — expect "Update Available".
3. Check `Sasih.dmg` downloads and mounts; drag-to-Applications works; Gatekeeper accepts the notarized app.
4. If anything failed post-publish: fix forward with a patch release; do not mutate the published artifacts.

## Release checklist (copy into the release commit or exec-plan)

- [ ] Owner approval obtained
- [ ] `./test.sh` green
- [ ] Hardware matrix complete on this build
- [ ] Both Info.plist version keys bumped; convention-consistent commit
- [ ] Signed with `$SASIH_SIGNING_IDENTITY`
- [ ] DMG notarized (`--wait`), stapled, `spctl` accepted
- [ ] GitHub Release `vX.Y.Z` published, full release, DMG attached
- [ ] `releases/latest` returns the new tag; in-app check sees it
- [ ] Docs/deployment updated if the pipeline changed
