# Exec Plan: enable-on-already-on-panel leaves stuck "off" state

> Status: [ ] Code complete; QA hardware matrix pending
> Created: 2026-10-20
> Repo: mac-app-blackout (single-repo workspace)
> Agent(s): macOS Engineer; QA (hardware matrix pending)
> Touches: `Sources/SasihCore/DisplayManager.swift`, `Tests/SasihCoreTests/DisplayManagerTests.swift`, docs: `trd/…/stack-architecture.md`, `erd/relationships.md`, `erd/entities.md`, `api-contracts/errors.md`, `QUALITY_SCORE.md`

## Goal

Make `enableInternalDisplay()` converge to observed reality so a panel that is already on can never leave the persisted `IsInternalDisplayOff` flag stuck at `true` and surface "Failed to enable internal display." forever.

## Field report

User ran Blackout, then rebooted the Mac and relaunched the app. Every launch shows **"Failed to enable internal display."** and the Blackout switch stays in the off-state; it cannot be cleared from the UI.

## Root cause

1. `disableInternalDisplay()` persists `IsInternalDisplayOff = true`.
2. A reboot clears the WindowServer disable flag (documented: the disable does not survive reboot) but **does not** clear UserDefaults.
3. On next launch, `restoreOnLaunchIfNeeded()` sees the persisted `true` and calls `enableInternalDisplay()`, which unconditionally issues `SLSConfigureDisplayEnabled(id, 1)` (contract: "never issue a change for a display already in the target state — it fails the whole transaction").
4. The transaction fails, so `lastError` is set and the off-state is (correctly, by the old rule) left `true`. Because the panel is already on, every retry — launch, backstop tick, manual toggle — hits the same doomed no-op and the app can never converge.

The disable path already has the symmetric idempotency guard (`internal display already offline → record off, no hardware call`); the enable path was missing it.

## Scope

- In: re-check reality after a failed enable transaction; refresh a stale cached display ID whenever the live builtin is visible; regression tests; invalidated docs.
- Out: private SkyLight wrapper/transaction shape, disable path, wake decision, UI copy, persisted key names.

## Approach

- Always attempt the SkyLight enable (no pre-check shortcut — see decision log).
- If the transaction fails, re-read the online list before declaring failure; if the builtin is online (already on after a reboot, or macOS restored it concurrently), record on (persist `false`, clear `lastError`, refresh the cached ID) and return `true`. Otherwise keep the existing failure discipline: `lastError` set, off-state untouched.
- Update the fake-driven tests that implicitly modelled "panel still online after disable" (unrealistic) and add regressions for the reboot scenario.

## Steps

1. [x] Post-failure reality check in `enableInternalDisplay()` (pre-check shortcut added then removed — see decision log)
2. [x] Regression tests: stale off-state after reboot, stale cached ID refresh, failed-but-converged transaction, genuine failure still errors
3. [x] Fix test fixtures that leave the panel online after a successful disable
4. [x] Update invalidated docs
5. [x] `./test.sh` green (88/88)
6. [ ] Hand QA the hardware rows (see Success criteria)

## Success criteria

- `./test.sh` fully green, including:
  - `enableWhenPanelAlreadyOnlineHealsAfterRejectedNoOp`
  - `enableStillAttemptsHardwareRestoreWhenOnlineListShowsPanel`
  - `restoreOnLaunchHealsStaleOffStateAfterReboot`
  - `enableRefreshesStaleCachedIDFromOnlineBuiltin`
  - `enableTreatsPanelAppearingAfterFailedTransactionAsSuccess`
  - `enableFailureWhenPanelStaysOffSurfacesError`
- Manual hardware matrix (QA, per `playbooks/hardware-verification.md` §3, `DisplayManager` change → rows **1–13**; high-value: 2, 5, 6, 10, 12):
  - Row 6/10 reproduced: persist off-state, reboot (panel returns), launch → no error, switch shows on, `IsInternalDisplayOff` cleared.
  - Row 2: normal toggle back on still restores the panel and clears the flag.
- No safety net weakened: a genuinely offline panel still gets the hardware enable attempt, and a real failure still leaves the off-state recorded so retries continue.

## Open questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Does `CGGetOnlineDisplayList` ever list a panel that is enabled-but-not-drawable? | macOS Engineer | — | If it did, recording on would be wrong; treat `online` as ground truth consistent with the existing disable-path assumption and verify on hardware row 2/10. |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-10-20 | ~~Treat "builtin present in `onlineDisplayIDs()`" as already-enabled and skip the transaction~~ — **reverted same day** | Review: "present ⇒ on" is stronger than the disable path's "absent ⇒ off"; the online list can retain ghost/non-drawable entries (2026-09-22 decision), so the shortcut could silently skip a real restore. The post-failure re-check alone fixes the field bug |
| 2026-10-20 | Re-check online list after a failed enable before surfacing the error | Prevents a benign race (macOS restores concurrently) from pinning the app in a permanent error state |
