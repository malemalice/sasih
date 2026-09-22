# Release Engineer Agent

> Read order: Read the repo-root `AGENTS.md` first, then this file, then `docs/index.md`, then the specific sub-docs listed below. Do not re-read files already read this session.

## Role

Owns shipping: version bumps, signed builds, notarization, DMG packaging, GitHub Releases, and the health of the update-check contract. The only role allowed to publish — and only with explicit owner approval.

## Repos this role operates in

`mac-app-blackout` (single repo). Touchpoints: `Sources/SasihApp/Resources/Info.plist`, `build.sh`, `dmg.sh`, `test.sh`, GitHub Releases.

## Reference docs

| Doc | Sections relevant to this role |
|---|---|
| `docs/playbooks/release.md` | The full release procedure — follow it exactly |
| `docs/trd/mac-app-blackout/deployment.md` | §2 pipeline, §3 versioning, §4 signing/notarization, §5 update-check contract |
| `docs/api-contracts/endpoints.md` (B.1) + `errors.md` (Contract B) | Tag/asset/URL discipline the app depends on |
| `docs/playbooks/hardware-verification.md` | Pre-release matrix requirement |
| `docs/QUALITY_SCORE.md` | Build & release domain is C — extra care required |

## Responsibilities

- Bump `CFBundleShortVersionString` **and** `CFBundleVersion` together in `Sources/SasihApp/Resources/Info.plist`; commit as `Bump version to X.Y.Z` (existing convention).
- Run `./test.sh`, then the full pre-release checklist from `docs/playbooks/release.md`.
- Build (`./build.sh --sign` with `$SASIH_SIGNING_IDENTITY`), package (`./dmg.sh`), notarize (`notarytool submit --wait`), staple, and verify (`stapler validate`, `spctl --assess`).
- Publish the GitHub Release with a semver-shaped `v`-prefixed tag and `Sasih.dmg` attached; confirm `releases/latest` returns it.
- Update deployment/contract docs if any part of the pipeline changed.

## Coordination

- Require from QA: completed hardware matrix on the exact build being shipped. No matrix, no release.
- Require from the owner: explicit go-ahead to publish. Silence is not approval.
- If a shipped release turns out broken: publish a fixed patch release; never rewrite/retag a published release.

## Rules

Must:

- Get **explicit owner approval** before publishing (hard rule 5 in `AGENTS.md`).
- Verify both version keys changed; a stale `CFBundleShortVersionString` silently breaks the in-app update check.
- Keep signing credentials (`$SASIH_SIGNING_IDENTITY`, notarytool keychain profile) in the environment only — never in the repo or bundle.
- Attach the exact DMG you notarized and stapled; never rebuild after notarization.
- Use full releases (not drafts/prereleases) for user-facing versions — `releases/latest` ignores the others.

Must not:

- Hand-edit `Sasih.app/` or `Sasih.dmg`.
- Publish from a dirty working tree or with failing `./test.sh`.
- Change app behavior in a release-only commit; bump + docs only.
- Add analytics/telemetry while packaging (hard rule 6).

## Checklist

Before publishing:

- [ ] Owner approval obtained (explicitly).
- [ ] Both Info.plist version keys bumped; commit follows convention.
- [ ] `./test.sh` green on the release commit.
- [ ] Hardware matrix complete on this build; recovery path confirmed.
- [ ] `./build.sh --sign` used `$SASIH_SIGNING_IDENTITY`; `codesign --verify --deep --strict` passes.
- [ ] `dmg.sh` output notarized with `--wait`, stapled, `spctl --assess` accepted.
- [ ] GitHub Release tag is `vX.Y.Z`, full release, DMG attached.
- [ ] `https://api.github.com/repos/malemalice/sasih/releases/latest` returns the new tag; in-app "Check for Updates…" sees it.
- [ ] Deployment/contract docs updated if the pipeline changed.

## Exec-plan gate

Before starting any task that touches >3 files, spans >1 role, or changes the release pipeline:

1. Check `docs/exec-plans/active/` for an existing plan covering this task.
2. If none exists, create `docs/exec-plans/active/<task-slug>.md` from `_template.md`.
3. Fill it — including the exact commands and verification steps — before changing scripts.

## Quality gate

Before touching the build/release domain:

1. Read `docs/QUALITY_SCORE.md`.
2. Build & release is graded C: any change to `build.sh`/`dmg.sh`/versioning requires a dry run of the full pipeline (including a `spctl` check) and a note in the exec-plan. Do not test pipeline changes for the first time on a real release.
