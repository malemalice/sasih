# Quality Score

> Read before touching any domain. Extra caution required for C or below.
> Scoring: A = excellent | B = acceptable | C = needs work | D = critical risk
> Scored: 2026-09-22 (initial harness adoption).

## Domain scores

| Domain | Where | Score | Test coverage | Notes |
|---|---|---|---|---|
| Display state logic (`DisplayManager`, guards, diff, sleep/wake) | `Sources/SasihCore/*.swift` | **B** | Strong unit coverage via injected fakes (`Tests/SasihCoreTests`) | Well-factored pure logic; deducted from A only because nothing runs it automatically (TD-001) |
| Private API transaction layer | `Sources/SasihCore/PrivateAPI/` | **C** | Symbol-resolution fallback fully unit-tested; real `dlopen`/transaction against SkyLight is **not** automatable | Behaviour can only be verified on hardware; macOS release can break it silently across the whole app (TD-008) |
| Persistence (`DisplayIDStore`) | `Sources/SasihCore/DisplayIDStore.swift` | **B** | Round-trip, fallback-order, corrupt-file covered | — |
| App lifecycle & safety nets (`AppDelegate`) | `Sources/SasihApp/AppDelegate.swift` | **C** | None (timing-dependent; diagnostics-by-logging only) | Highest-consequence code in the app — a mistake here strands a user with a black screen. Manual matrix is the only gate (TD-002) |
| Touch Bar recovery | `Sources/SasihApp/TouchBarRecovery.swift` | **B** | Unit-tested via injected `ProcessRunning`/delay fakes | Known gap on automatic paths (TD-003) |
| UI (`MenuBarView`, `SasihApp`) | `Sources/SasihApp/` | **C** | Blackout switch binding + view model behaviour automated; rest manual only | Low blast radius, but treat copy/state changes with care (TD-006) |
| Build & release scripts | `test.sh`, `build.sh`, `dmg.sh` | **C** | None; manual pipeline | Unsigned DMGs can ship by accident; version bump is manual/duplicated (TD-004, TD-005) |
| Docs tree | `docs/` | **B** | n/a | Authored and fresh as of 2026-09-22; will decay without a refresh rule (see below) |

## Rules

- **A**: No special action required
- **B**: Maintain current coverage; do not reduce
- **C**: Write (or extend) a test for the affected path where possible; record the change in an exec-plan; if not automatable, state the manual scenarios run
- **D**: Escalate before touching; create exec-plan; require review sign-off

## Domain-specific cautions

- **Private API layer (C):** any change here also requires a hardware-matrix run (see `playbooks/hardware-verification.md`) — unit tests with fakes cannot prove real behaviour.
- **App lifecycle (C):** changes to timers, callbacks, or wake handling must be listed explicitly in the exec-plan and verified against at least manual scenarios 2, 7–11 of the matrix.
- **Build & release (C):** never publish a DMG without completing `playbooks/release.md` including notarization + stapling.

## Score history

| Date | Domain | Old | New | Changed by |
|---|---|---|---|---|
| 2026-09-22 | (all) | — | initial scores above | harness adoption |
| 2026-09-22 | Display state logic | B | B | Added 8 regression tests for non-drawable/ghost externals + screen-sleep deferral (`ghost-external-stranding`); real-hardware matrix rows 18–20 still pending QA |
