# Auth

## Contract A — private SkyLight symbol

- **No entitlement, no auth check reachable by third parties.** `SLSConfigureDisplayEnabled` works from a plain `dlopen`/`dlsym` with standard code signing. This is the entire reason it was chosen over the "correct" clamshell-state API, which requires `com.apple.private.SkyLight.displaypowercontrol` — an entitlement AMFI refuses to grant non-Apple-signed binaries.
- **Do not** attempt the entitlement path (see `trd/mac-app-blackout/decisions.md`); it is a confirmed dead end.

## Contract B — GitHub Releases API

- **Unauthenticated.** No token, no OAuth, no API key anywhere in the app (and none may be added — a shipped client cannot hold a secret).
- **Consequence:** the 60-requests/hour/IP unauthenticated rate limit applies. It is more than sufficient for a manual "Check for Updates…" action, but it means:
  - update checks must only run on explicit user action — never on a timer or on launch;
  - a 403 from rate limiting degrades to `.failed` like any other failure, with no retry loop.

## App-side secrets

There are none. Signing/notarization credentials live only in the release engineer's environment (`$SASIH_SIGNING_IDENTITY`, `notarytool` keychain profile) — never in the repo, never in the app bundle.
