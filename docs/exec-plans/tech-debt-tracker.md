# Technical Debt Tracker

> Updated by: any agent that discovers debt during a task. Single-repo workspace
> (`mac-app-blackout`). Severity: H = can strand/crash a user | M = real risk, scheduled
> | L = cosmetic/opportunistic.

## Open Items

| ID | Repo | Area | Description | Severity | Discovered | Owner |
|---|---|---|---|---|---|---|
| TD-001 | mac-app-blackout | CI | No CI at all (`.github/` absent). Unit tests only run when a human runs `./test.sh`. | M | 2026-09-22 | — |
| TD-002 | mac-app-blackout | App lifecycle | `AppDelegate` timing-dependent paths (2s wake delay, 10s backstop, reconfiguration callback flurry) have **no automated tests** — the code comments say they can't be reproduced under test. Only unified-log diagnostics exist. | M | 2026-09-22 | — |
| TD-003 | mac-app-blackout | Touch Bar | After an *automatic* re-enable (unplug fallback / wake), the Touch Bar may stay blank until one manual toggle — the nudge is deliberately not run on those paths (race with our own reconfiguration callbacks). Documented trade-off, no fix scheduled. | M | 2026-09-22 | — |
| TD-004 | mac-app-blackout | Release | Notarization is a manual, undocumented-in-repo step (needs Apple ID credentials). No script, no checklist automation; `dmg.sh` produces an unsigned DMG by default. | M | 2026-09-22 | — |
| TD-005 | mac-app-blackout | Release | Version bump is manual and duplicated across two Info.plist keys (`CFBundleShortVersionString` + `CFBundleVersion`) — easy to forget one, which silently breaks `UpdateChecker` comparisons. | M | 2026-09-22 | — |
| TD-006 | mac-app-blackout | UI | `MenuBarView` is mostly untested (the Blackout switch binding now has a regression test); rest of UI verification is manual only. Acceptable for now, but noted. | L | 2026-09-22 | — |
| TD-007 | mac-app-blackout | Hygiene | `SasihSpike` is a throwaway spike target still in the package; build artifacts (`Sasih.app`, `Sasih.dmg`) are gitignored but present in the working tree. | L | 2026-09-22 | — |
| TD-008 | mac-app-blackout | Compatibility | Private-API behaviour is unverified on macOS 14/15/16 (this machine's version is the only one tested). Re-verification is a manual matrix run per upgrade. | M | 2026-09-22 | — |
| TD-009 | mac-app-blackout | Landing page | Deferred by plan until a screenshot/GIF + final icon exist; no artifact yet. | L | 2026-09-22 | — |
| TD-010 | mac-app-blackout | App lifecycle | Emergency-check reconciliation treats a panel absent from `CGGetOnlineDisplayList` as ground truth inside fallback windows. A sub-tick reconfiguration blip while the panel is physically on could theoretically mis-record state as off (no stranding; converges on the next external cycle). Steady-state logs show stable online lists — no observed occurrence. | L | 2026-09-22 | — |
| TD-011 | mac-app-blackout | Compatibility | A stale display entry that still reports `CGDisplayIsActive` (a fully ghost-impersonating display) cannot be distinguished from a real drawable external using public CG queries; blackout could in principle outlive a hidden display in that exact case. Mitigations: drawable-external predicate, active-count guard, `screensAreAsleep` deferral, and log correlation during matrix row 19. | M | 2026-09-22 | — |

## Resolved Items

| ID | Repo | Area | Resolution | Resolved |
|---|---|---|---|---|
| — | — | — | — | — |
