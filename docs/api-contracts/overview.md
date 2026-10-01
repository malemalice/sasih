# Overview

## Contract A — private SkyLight symbol (in-process ABI)

- **Transport:** `dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)` + `dlsym` at runtime; never link-time.
- **Symbol names:** `SLSConfigureDisplayEnabled` (primary) → `CGSConfigureDisplayEnabled` (fallback) — first resolvable wins.
- **Transaction discipline:** the symbol must be called inside a public CG display-configuration transaction (`CGBeginDisplayConfiguration` → call → `CGCompleteDisplayConfiguration(.forSession)`), with `CGCancelDisplayConfiguration` on failure.
- **Versioning policy:** none exists; Apple may change the symbol, its signature, or its error behaviour in any release. The mitigation is *graceful degradation*: if neither symbol resolves, `setDisplay` returns `false` and the UI shows `lastError` — never crash, never silently no-op, never leave a black screen.
- **Compatibility gate:** re-verify on every macOS upgrade (see `playbooks/hardware-verification.md`). Apple Silicon + macOS 13+ only.

## Contract B — GitHub Releases REST API

- **Transport:** HTTPS, JSON; `URLSession.shared.data(for:)`.
- **Base:** `https://api.github.com` — unauthenticated.
- **Versioning policy:** GitHub API is versioned by header in general; this repo pins behaviour by using only `releases/latest` with `Accept: application/vnd.github+json`, whose shape is stable. *Our* side of the contract is release discipline:
  1. release tag must be semver-shaped, optionally `v`-prefixed (`v0.1.4`) — legacy `v` is stripped before comparison;
  2. the release must be published (not draft/prerelease) to be returned as `latest`;
  3. `html_url` must be a valid URL — the app opens it in the browser, it does not download assets programmatically.
- **Failure policy:** any failure (network, non-200, decode, bad URL) degrades to `.failed(...)` and a plain alert. Update checking is best-effort and must never affect display functionality.

## Contract C — persisted state

- **Transport:** in-process — `UserDefaults.standard` primary, `~/.sasih_internal_display_id` backup file (see `docs/erd/`).
- **Shape (owned by the ERD, not this folder):** `BackupInternalDisplayID` (Int), `IsInternalDisplayOff` (Bool, default false), `AutoRevertInternalOffOnReconnect` (Bool, default true), `StayAwakeEnabled` (Bool, default false — unrelated to display-off state, see `docs/erd/entities.md` §1b).
- **Versioning policy:** none; keys are stable and additive. But **write semantics are part of the contract**: when each key is written, kept, or reconciled is what the crash/wake safety nets rely on — changing that behaviour is a contract change even when no key/type/default changes.
- **Failure policy:** a missing/corrupt store must degrade to the safe direction (assume "on"), never to a state that could strand the user (see `docs/erd/notes.md`).

## Single source of truth

Any change to these contracts requires updating this folder (and `docs/erd/` for C) **before** merging the code change, with an entry in `changes.md`.
