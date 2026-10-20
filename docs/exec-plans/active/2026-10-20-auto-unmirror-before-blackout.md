# Exec Plan: auto-unmirror-before-blackout

> Status: [ ] Code complete; QA hardware matrix pending
> Created: 2026-10-20
> Repo: mac-app-blackout (single-repo workspace)
> Agent(s): macOS Engineer; Designer (copy/states); QA (hardware matrix pending)
> Touches: `Sources/SasihCore/DisplayInfoProvider.swift`, `Sources/SasihCore/PrivateAPI/DisplayConfiguring.swift`, `Sources/SasihCore/DisplayManager.swift`, `Sources/SasihApp/DisplayStateViewModel.swift`, `Sources/SasihApp/MenuBarView.swift`, `Tests/SasihCoreTests/DisplayManagerTests.swift`, `Tests/SasihAppTests/DisplayStateViewModelTests.swift`, docs: `trd/…/stack-architecture.md`, `trd/…/decisions.md`, `api-contracts/overview.md`, `api-contracts/endpoints.md`, `api-contracts/changes.md`, `api-contracts/errors.md`, `erd/relationships.md`, `erd/entities.md`, `erd/repo-mapping.md`, `design-system/components.md`, `design-system/accessibility.md`, `agents/designer.md`, `references/…/coregraphics-display-configuration.md`, `playbooks/hardware-verification.md`, `QUALITY_SCORE.md`

## Goal

When the only external display is in macOS hardware mirror mode, turning Blackout on stops the mirroring automatically and then applies the blackout, instead of disabling the switch with "Connect an external display to turn this off." while a display is plainly connected.

## Field evidence (2026-10-20)

- External **LS27D300G** connected and showing the desktop, in hardware mirror mode with the built-in "Color LCD" as **Master Mirror**.
- A hardware-mirror external is *online* but not *active/drawable* (`CGDisplayIsActive == 0`), so `usableExternalDisplayCount == 0` (the 2026-09-22 usable-external rule, correct by design).
- Result: Blackout switch disabled with "Connect an external display to turn this off." — confusing for a connected display. Users are non-technical; the owner asked for the fix to be automatic rather than a "turn off Mirror in System Settings" instruction.

## Scope

- In: detect mirrored externals; stop mirroring (public CoreGraphics, session-scoped) when blackout is requested; apply blackout through the normal guarded disable once the external is drawable; pending state + timeout; Auto-Blackout reconnect into mirror mode; UI copy/state for the pending window; tests; invalidated docs.
- Out: re-mirroring when Blackout is turned off (see open questions); changes to the SkyLight disable/enable transaction; persisted keys; the usable-external guard itself.

## Approach

- `DisplayInfoProviding.mirroredExternalDisplayIDs()` (default `[]`): real impl = online, non-builtin, not in the active list, `CGDisplayIsInMirrorSet != 0`.
- `DisplayConfiguring.stopMirroring(_ ids:) -> Bool` (default `false`): real impl uses **public** API — `CGBeginDisplayConfiguration` → `CGConfigureDisplayMirrorOfDisplay(config, id, kCGNullDirectDisplay)` per id → `CGCompleteDisplayConfiguration(.forSession)`, `CGCancelDisplayConfiguration` on any per-id failure. Both screens stay on; it never darkens anything.
- `disableInternalDisplay()`: when the usable-external guard refuses **and** mirrored externals exist → `stopMirroring`. Success: in-memory `isBlackoutPendingUnmirror = true`, deadline = `now() + unmirrorTimeout` (15 s, monotonic `systemUptime` via injectable `now`), clear `lastError`, return `false` (no SkyLight call yet). Failure: `lastError = "Couldn't stop screen mirroring. Turn off Mirror in System Settings → Displays."`, return `false`. No mirrored external → unchanged "No external display detected." refusal.
- `performEmergencyCheckIfNeeded` (after the screens-asleep deferral), while pending:
  - usable external now > 0 → clear pending, call `disableInternalDisplay()` (every guard re-runs); success clears `internalOnIsFallback`;
  - deadline passed → clear pending, set the "Couldn't stop screen mirroring…" error;
  - otherwise wait (early return) **only while the builtin is online**; if it isn't, fall through to the normal reconciliation/restore logic.
- Auto-Blackout reconciliation triggers on `usable > 0 || mirrored non-empty`, so a reconnect that macOS puts back into mirror mode goes through the same un-mirror-then-disable path.
- `toggle()` while pending cancels it ("never mind") — no hardware call.
- App: `hasExternalDisplay = usable > 0 || mirrored > 0`; `isBlackoutPending`; `isBlackoutShownActive = isInternalDisplayOff || isBlackoutPending` drives the switch (no bounce while pending) and `setBlackoutActive` compares against it. Caption "Starting blackout…" while pending.

## Safety argument

No safety net is weakened:

1. The blackout is still **only** applied by `disableInternalDisplay()` with both guards (`canDisableInternal` on a *usable* external, `isLastActiveDisplay`) re-evaluated at apply time. Un-mirroring only changes the inputs those guards see; it does not bypass them.
2. Un-mirroring cannot produce a dark screen: both displays stay on; the worst case is an extended desktop the user didn't ask for (see open question).
3. The pending wait is bounded (15 s, monotonic) and only holds while the builtin panel is online; otherwise the emergency check proceeds exactly as before.
4. The screens-asleep deferral runs before the pending branch, so display sleep can neither apply nor time out a pending blackout spuriously.
5. Pending state is in-memory only — a crash/relaunch starts with nothing pending; no new persisted key, no change to persisted write semantics.

## Steps

1. [x] `mirroredExternalDisplayIDs()` + `stopMirroring(_:)` protocol requirements with safe defaults; real impls
2. [x] Pending-unmirror state, timeout, emergency-check branch, toggle cancel, Auto-Blackout trigger in `DisplayManager`
3. [x] View model / menu: `hasExternalDisplay`, `isBlackoutPending`, `isBlackoutShownActive`, "Starting blackout…"
4. [x] Tests (see Success criteria); `./test.sh` 97/97 green
5. [x] Update invalidated docs
6. [ ] Hand QA the hardware rows (see Success criteria)

## Success criteria

- `./test.sh` fully green (97/97), including:
  - `disableWithMirroredExternalStopsMirroringAndWaits`
  - `pendingBlackoutWaitsWhileExternalIsStillMirrored`
  - `pendingBlackoutAppliesOnceExternalIsDrawable`
  - `pendingBlackoutDefersWhileScreensAsleep`
  - `pendingBlackoutGivesUpAfterTimeout`
  - `stopMirroringFailureSurfacesErrorAndLeavesPanelOn`
  - `toggleWhileBlackoutPendingCancelsIt`
  - `autoRevertStopsMirroringWhenExternalReconnectsMirrored`
  - (app) `mirroredExternalStillAllowsBlackout`
- Manual hardware matrix (QA, per `playbooks/hardware-verification.md` §3 "Mirror handling" → rows **1–4, 13, 15, 16, 20, 21, 22**):
  - Row 20 with the field setup (external mirroring the built-in as Master Mirror): switch is enabled, mirroring stops, both screens stay on, then within a few seconds the internal goes dark and the external shows the desktop.
  - Row 21: Auto-Blackout reconnect into mirror mode re-applies blackout.
  - Row 22: toggling back during "Starting blackout…" cancels; no blackout follows.

## Open questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Should turning Blackout off re-mirror the displays we un-mirrored? | Product Manager | — | Open. Today the display stays extended until next login (`.forSession` restores the user's mirror preference then). Re-mirroring would need us to remember the original mirror topology (master + members) in memory and replay it on enable. |
| Does macOS ever reject `CGConfigureDisplayMirrorOfDisplay(…, kCGNullDirectDisplay)` for an external that is the *master* of a mirror set (built-in mirroring the external)? | macOS Engineer / QA | — | Field case had the built-in as master. Verify the reverse topology on hardware row 20; failure path surfaces the "Couldn't stop screen mirroring…" error, never a dark screen. |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-10-20 | Stop mirroring automatically instead of showing a "turn off Mirror" hint | Users are non-technical; the owner asked for it to be automatic. The error text is kept only as the fallback when un-mirroring fails or times out |
| 2026-10-20 | Use public `CGConfigureDisplayMirrorOfDisplay(id, kCGNullDirectDisplay)` inside a CG configuration transaction | Public, documented API; no new private symbol. Same transaction discipline as Contract A (begin → configure → complete, cancel on failure) |
| 2026-10-20 | Complete with `.forSession`, not `.permanently` | The user's own mirror preference must come back at next login; we change it only for the session in which they asked for blackout |
| 2026-10-20 | Don't disable in the same call; wait for the external to become drawable and apply via the guarded `disableInternalDisplay()` | macOS reconfigures asynchronously; the usable-external guard must see a really drawable external. Keeps every existing guard authoritative |
| 2026-10-20 | 15 s timeout on a monotonic clock (`systemUptime`, injectable for tests) | Un-mirroring normally settles in a few seconds; a bound prevents an indefinite "Starting blackout…" state; wall-clock changes can't skew it |
| 2026-10-20 | No re-mirror when Blackout is turned off (for now) | Keeps scope minimal and avoids recording/replaying mirror topology; `.forSession` restores the preference at next login. Tracked as an open question |
| 2026-10-20 | Switch shows "on" while pending; toggling during pending cancels | Prevents the switch bouncing off-then-on during the un-mirror window; cancelling is the natural reading of flipping it back |
