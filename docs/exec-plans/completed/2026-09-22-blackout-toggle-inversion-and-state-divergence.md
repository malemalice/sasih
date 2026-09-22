# Exec Plan: Blackout toggle inversion + state/reality divergence

> Status: [x] Complete (code, tests, build, deployed locally; manual hardware matrix **pending** — see Success criteria)
> Created: 2026-09-22
> Repo: mac-app-blackout (single-repo workspace)
> Agent(s): macOS Engineer (session on 2026-09-22), QA manual matrix outstanding
> Touches: `Sources/SasihApp/MenuBarView.swift`, `Sources/SasihApp/DisplayStateViewModel.swift`, `Sources/SasihCore/DisplayManager.swift`, `Tests/SasihAppTests/DisplayStateViewModelTests.swift`, `Tests/SasihCoreTests/DisplayManagerTests.swift`, `docs/design-system/components.md`, `docs/trd/mac-app-blackout/stack-architecture.md`, `docs/erd/entities.md`

## Goal

Restore the core truthfulness invariant: the Blackout switch position and the recorded `isInternalDisplayOff` state must agree with the physical internal panel.

## Scope

- In: menu-bar switch binding semantics; `handleWake()` `leaveOn` fallback verification; emergency-check reconciliation; idempotent `disableInternalDisplay()` on an offline panel; regression tests; invalidated docs.
- Out: `SleepWakeDecision` shape (still pure), `TouchBarRecovery`, Auto-Blackout preference semantics, private SkyLight transaction/wrapper (untouched).

## Invariants breached (field-evidenced)

1. **UI**: `MenuBarView.toggleBinding` was `get: { !isInternalDisplayOff }` — correct for the pre-rename row "Built-in Display", wrong after commit `315d68c` renamed it to "Blackout" (`docs/design-system/components.md` documented the inverted binding). Result: switch OFF while blackout active. Live evidence 2026-09-22: `IsInternalDisplayOff=1`, log `onlineIDs=[2] externalCount=1` (panel physically off), caption "Blackout active" but switch rendered off.
2. **State vs reality**: `handleWake()` `.leaveOn` recorded `isInternalDisplayOff=false` on the assumption macOS re-enabled the panel during wake. When that assumption failed (the state-loss class this app exists for), memory + persisted flag said "on" while the panel was off. Field log 2026-09-21 07:41–13:58: `isInternalDisplayOff=false internalOnIsFallback=true onlineIDs=[285] externalCount=1`, with `disableInternalDisplay: refused — would be the last active display` repeating every 10 s — auto-revert retried a no-op disable forever because the fallback flag was only cleared on success.

## Why the fix restores the invariant

- Binding now reads `isInternalDisplayOff` directly and writes through `DisplayStateViewModel.setBlackoutActive(_:)`, which no-ops when the desired value already matches — so an auto-revert that flips state between render and click cannot invert the outcome.
- `leaveOn` verifies the panel is actually online before recording "on"; if not, it calls `enableInternalDisplay()` explicitly and, on failure, keeps "off" recorded so the emergency check and launch restore keep retrying.
- `performEmergencyCheckIfNeeded()` reconciles first: a panel absent from the online list is ground truth; when the recorded state says "on" and either no external is present or the internal-on was a fallback, the state is recorded off before any reapply decision. This stops the infinite retry and heals diverged persisted states.
- `disableInternalDisplay()` treats an already-offline panel as success and records the off-state without a hardware call (the private call fails the whole transaction when a display is already in the target state), removing the false "last active display" refusal path.

## Steps

1. [x] Fix binding + intent-based setter
2. [x] Fix `handleWake` `leaveOn`
3. [x] Emergency-check reconciliation
4. [x] Idempotent `disableInternalDisplay`
5. [x] Regression tests (7 new: 5 core, 2 app)
6. [x] `./test.sh` green (60/60) and `./build.sh` succeeds
7. [x] Update invalidated docs (components, stack-architecture, entities)
8. [ ] QA manual matrix (below)

## Success criteria

- `./test.sh`: 60/60 passing, including new tests:
  - `disableWhenPanelAlreadyOfflineRecordsStateWithoutHardwareCall`
  - `handleWakeDoesNotTouchHardwareWhenMacOSRestoredPanel`
  - `handleWakeRestoresInternalWhenMacOSDidNot`
  - `handleWakeKeepsOffRecordedWhenRestoreFails`
  - `emergencyCheckReconcilesFallbackPanelAlreadyOffline`
  - `emergencyCheckRestoresPanelWhenStateSaidOnButPanelOffline`
  - `setBlackoutActiveIsIntentBasedAndIdempotent`, `blackoutSwitchBindingMatchesStateNotItsInverse`
- **Manual hardware matrix (pending)** — per `playbooks/hardware-verification.md` §3, this change touches `DisplayManager` + sleep/wake + Auto-Blackout + menu-bar UI: rows **1–13, 15, 16** (row 17 only if TouchBarServer present). Highest-value rows for this fix: 2, 8, 9, 15, 16 (wake fallback + auto-revert loop); the 9/21 field sequence is reproduced by row 15.
- Deployment: fixed build installed to `/Applications/Sasih.app` and relaunched 2026-09-22 07:56; quit path restored the panel cleanly before exit (log-verified).

## Open questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Can the reconciliation's "panel absent" observation misfire on a sub-tick reconfiguration blip inside a fallback window? | macOS Engineer | — | Theoretical only (steady-state logs show stable `onlineIDs`); tracked as TD-010 |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-22 | Reconcile recorded state from the online list inside the emergency check, before reapply decisions | Fixes the stuck fallback flag loop without weakening the last-active-display guard; makes recorded state converge on observed reality |
| 2026-09-22 | Keep `SleepWakeDecision` pure; put the verify/enable logic in `handleWake` | Decision enum stays trivially testable; hardware interaction stays in `DisplayManager` |
| 2026-09-22 | `disableInternalDisplay()` returns success for an already-offline panel without a hardware call | Private API fails a transaction for an already-target-state display; recording truth is the correct postcondition |
| 2026-09-22 | Binding writes through an intent-based setter instead of `toggle()` directly | Immune to state changing between render and click (auto-revert) |
