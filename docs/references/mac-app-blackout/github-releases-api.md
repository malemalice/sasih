# GitHub Releases API Reference

> Repo: mac-app-blackout
> Version: REST v3 (`releases/latest` shape, stable)
> Source: GitHub REST API docs — https://docs.github.com/rest/releases/releases
> Last updated: 2026-09-22

## Overview

`UpdateChecker` reads this repo's own latest release to tell the user whether a newer version exists. Unauthenticated, user-triggered, best-effort only. Full contract: `docs/api-contracts/`.

## Key API used in this repo

```
GET https://api.github.com/repos/malemalice/sasih/releases/latest
Accept: application/vnd.github+json
```

Decoded fields (Swift `GitHubRelease`): `tag_name` → `tagName`, `html_url` → `htmlURL` (explicit `CodingKeys`).

Comparison: strip one leading `v` from `tag_name`, then `VersionComparison.isNewer(latest, than: CFBundleShortVersionString)`.

## Common patterns

- Treat every non-200 and every decode failure as `.failed` — never retry, never block UI.
- Only `releases/latest` (full releases). Drafts/prereleases are excluded by GitHub's own semantics.

## Gotchas

- **Rate limit (unauthenticated): 60 requests/hour/IP.** Fine for a manual action; do not add launch-time or periodic checks.
- A repo with no published releases returns 404 — handle as generic failure.
- Our own release discipline is part of this contract: tags must be semver-shaped with an optional `v` prefix (`v0.1.4`); a tag like `release-1` breaks version comparison (it would compare as garbage). `VersionComparisonTests` covers the parser, not the tag hygiene.
- `CFBundleShortVersionString` is read at call time from `Bundle.main`; in tests/bare executables it falls back to `"0.0.0"`.
- `html_url` must parse as a `URL` — malformed values degrade to `.failed` rather than forced unwraps.

## Do not use

- Authenticated requests (no token may ship in a client app).
- `releases/latest` polling, hidden background checks, or auto-download of assets.
- Parsing `body`/changelog or assets — the app only opens the release page.
