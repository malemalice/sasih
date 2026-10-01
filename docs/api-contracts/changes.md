# Contract Change Log

> Every change that affects an external contract (private symbol usage, release/tag
> discipline, GitHub API usage, persisted-state write semantics) gets a row here **before**
> the code change merges.

| Date | Contract | Change | Breaking? | Notes |
|---|---|---|---|---|
| 2026-08-22 | A — SkyLight | Initial adoption of `SLSConfigureDisplayEnabled` with `CGSConfigureDisplayEnabled` fallback, inside `CGBeginDisplayConfiguration` transaction | n/a (initial) | Spike-verified on target hardware |
| 2026-08-22 | A — SkyLight | Persist internal display ID before disable; never re-issue a change for a display already in the target state | n/a | Per reference-implementation findings (transaction fails otherwise) |
| 2026-08-22 | B — GitHub Releases | Introduced `UpdateChecker` against `releases/latest` (unauthenticated, manual trigger only) | n/a (initial) | Requires semver-shaped `v`-prefixed tags |
| 2026-09-22 | A — SkyLight | No change — re-confirmed no alternative (entitlement path still unavailable) | No | Recorded during harness adoption |
| 2026-09-22 | C — Persisted state | Off-state write semantics now reconcile to the online display list: idempotent disable on an already-offline panel, emergency-check healing of diverged state, wake verifies/restores before recording "on" (keeps "off" recorded when the restore fails), Auto-Blackout reconnect loop removed | No — key names/types/defaults unchanged | Field-evidenced fix; details in `docs/exec-plans/completed/2026-09-22-blackout-toggle-inversion-and-state-divergence.md` |
| 2026-10-01 | C — Persisted state | New key `StayAwakeEnabled` (Bool, default false) added, owned by `Sources/SasihApp/StayAwake.swift`, not `DisplayIDStore`/`SasihCore` | No — additive, independent of existing keys | Backs the new "Stay Awake" toggle (`kIOPMAssertionTypePreventUserIdleDisplaySleep`); see decision log 2026-10-01 |
