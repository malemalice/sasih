# Exec Plan: auto-unmirror-before-blackout

> Status: [ ] Code complete; QA hardware matrix pending (un-mirror shipped in v0.1.8 / `3f2804f`; re-mirror on Blackout off added after, uncommitted)
> Created: 2026-10-20
> Repo: mac-app-blackout (single-repo workspace)
> Agent(s): macOS Engineer; Designer (copy/states); QA (hardware matrix pending)
> Touches: `Sources/SasihCore/DisplayInfoProvider.swift`, `Sources/SasihCore/PrivateAPI/DisplayConfiguring.swift`, `Sources/SasihCore/DisplayManager.swift`, `Sources/SasihApp/DisplayStateViewModel.swift`, `Sources/SasihApp/MenuBarView.swift`, `Tests/SasihCoreTests/DisplayManagerTests.swift`, `Tests/SasihAppTests/DisplayStateViewModelTests.swift`, docs: `trd/…/stack-architecture.md`, `trd/…/decisions.md`, `api-contracts/overview.md`, `api-contracts/endpoints.md`, `api-contracts/changes.md`, `api-contracts/errors.md`, `erd/relationships.md`, `erd/entities.md`, `erd/repo-mapping.md`, `design-system/components.md`, `design-system/accessibility.md`, `agents/designer.md`, `references/…/coregraphics-display-configuration.md`, `playbooks/hardware-verification.md`, `QUALITY_SCORE.md`

## Goal

When the only external display is in macOS hardware mirror mode, turning Blackout on stops the mirroring automatically and then applies the blackout, instead of disabling the switch with "Connect an external display to turn this off." while a display is plainly connected; turning Blackout off (or cancelling while it is starting) puts the mirroring back.

## Field evidence (2026-10-20)

- External **LS27D300G** connected and showing the desktop, in hardware mirror mode with the built-in "Color LCD" as **Master Mirror**.
- A hardware-mirror external is *online* but not *active/drawable* (`CGDisplayIsActive == 0`), so `usableExternalDisplayCount == 0` (the 2026-09-22 usable-external rule, correct by design).
- Result: Blackout switch disabled with "Connect an external display to turn this off." — confusing for a connected display. Users are non-technical; the owner asked for the fix to be automatic rather than a "turn off Mirror in System Settings" instruction.

## Scope

- In: detect mirrored externals; stop mirroring (public CoreGraphics, session-scoped) when blackout is requested; apply blackout through the normal guarded disable once the external is drawable; pending state + timeout; Auto-Blackout reconnect into mirror mode; UI copy/state for the pending window; tests; invalidated docs.
- In (follow-up, owner decision 2026-10-20): re-mirror the externals we un-mirrored when the user turns Blackout off or cancels a pending blackout.
- Out: re-mirroring after automatic restores (unplug emergency restore, wake `.leaveOn`); persisting mirror topology across relaunch; changes to the SkyLight disable/enable transaction; persisted keys; the usable-external guard itself.

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
- Re-mirror (follow-up): `DisplayConfiguring.startMirroring(_ ids:, of master:) -> Bool` (default `false`); the real impl shares a private `configureMirroring(ids, of:)` with `stopMirroring` (stop = master `kCGNullDirectDisplay`) — same public begin → `CGConfigureDisplayMirrorOfDisplay(config, id, master)` → complete(`.forSession`) / cancel transaction.
  - `DisplayManager` remembers `displaysToRemirror` (in-memory) only when **its own** `stopMirroring` succeeds. The master is always the builtin: un-mirroring only happens when no usable external exists, so the builtin was the only active display / mirror master.
  - Armed (`scheduleRemirror`, `remirrorTimeout` 15 s, same monotonic clock) only on user intent: a `toggle()` that turns Blackout off and whose enable succeeds, or a `toggle()` that cancels a pending blackout. It tries at once; `performEmergencyCheckIfNeeded` retries via `remirrorIfReady()` (after the screens-asleep deferral and the pending-unmirror block).
  - Mirrors only when the builtin is in the **active** list and the remembered externals are still active (filtered to those). A failed `startMirroring` retries until the deadline; on timeout it gives up silently — screens stay extended, no error (mirroring never darkens a screen).
  - Memory cleared (no re-mirror) on: emergency restore with no drawable external (unplug), `handleWake` `.leaveOn`, pending-unmirror timeout, or internal off/pending again at retry time.
- App: `hasExternalDisplay = usable > 0 || mirrored > 0`; `isBlackoutPending`; `isBlackoutShownActive = isInternalDisplayOff || isBlackoutPending` drives the switch (no bounce while pending) and `setBlackoutActive` compares against it. Caption "Starting blackout…" while pending.

## Safety argument

No safety net is weakened:

1. The blackout is still **only** applied by `disableInternalDisplay()` with both guards (`canDisableInternal` on a *usable* external, `isLastActiveDisplay`) re-evaluated at apply time. Un-mirroring only changes the inputs those guards see; it does not bypass them.
2. Un-mirroring and re-mirroring cannot produce a dark screen: both displays stay on; the worst case is an extended desktop the user didn't ask for (re-mirror timed out, or an automatic restore path). Re-mirror only runs once the builtin is active/drawable and after `isInternalDisplayOff` is already false, so it can never race a blackout.
3. The pending wait is bounded (15 s, monotonic) and only holds while the builtin panel is online; otherwise the emergency check proceeds exactly as before.
4. The screens-asleep deferral runs before the pending branch, so display sleep can neither apply nor time out a pending blackout spuriously.
5. Pending and re-mirror state are in-memory only — a crash/relaunch starts with nothing pending or remembered; no new persisted key, no change to persisted write semantics. `.forSession` remains the backstop: the user's own mirror setting returns at next login either way.
6. Re-mirror only undoes an un-mirror Sasih itself did, and only on explicit user intent — never after an unplug or a wake fallback.

## Steps

1. [x] `mirroredExternalDisplayIDs()` + `stopMirroring(_:)` protocol requirements with safe defaults; real impls
2. [x] Pending-unmirror state, timeout, emergency-check branch, toggle cancel, Auto-Blackout trigger in `DisplayManager`
3. [x] View model / menu: `hasExternalDisplay`, `isBlackoutPending`, `isBlackoutShownActive`, "Starting blackout…"
4. [x] Tests (see Success criteria); `./test.sh` 97/97 green
5. [x] Update invalidated docs
6. [x] Follow-up: `startMirroring(_:of:)`, `displaysToRemirror`/`remirrorDeadline`, `scheduleRemirror`/`remirrorIfReady`, clear-on-automatic-restore paths
7. [x] Follow-up tests; `./test.sh` 104/104 green
8. [x] Update invalidated docs for the follow-up
9. [ ] Hand QA the hardware rows (see Success criteria)

## Success criteria

- `./test.sh` fully green (104/104), including:
  - `disableWithMirroredExternalStopsMirroringAndWaits`
  - `pendingBlackoutWaitsWhileExternalIsStillMirrored`
  - `pendingBlackoutAppliesOnceExternalIsDrawable`
  - `pendingBlackoutDefersWhileScreensAsleep`
  - `pendingBlackoutGivesUpAfterTimeout`
  - `stopMirroringFailureSurfacesErrorAndLeavesPanelOn`
  - `toggleWhileBlackoutPendingCancelsIt`
  - `autoRevertStopsMirroringWhenExternalReconnectsMirrored`
  - (app) `mirroredExternalStillAllowsBlackout`
  - re-mirror follow-up: `blackoutOffRemirrorsOnceBuiltinIsBack`, `blackoutOffRemirrorsImmediatelyWhenBuiltinAlreadyDrawable`, `blackoutOffWithoutPriorUnmirrorNeverMirrors`, `remirrorGivesUpAfterTimeoutLeavingScreensExtended`, `emergencyRestoreAfterUnplugDoesNotRemirror`, `cancellingPendingBlackoutRemirrors`, `failedRemirrorRetriesThenSucceeds`
- Manual hardware matrix (QA, per `playbooks/hardware-verification.md` §3 "Mirror handling" → rows **1–4, 13, 15, 16, 20–23**):
  - Row 20 with the field setup (external mirroring the built-in as Master Mirror): switch is enabled, mirroring stops, both screens stay on, then within a few seconds the internal goes dark and the external shows the desktop.
  - Row 21: Auto-Blackout reconnect into mirror mode re-applies blackout.
  - Row 20 (continued): toggling Blackout off brings the internal back and, within a few seconds, the screens return to mirroring.
  - Row 22: toggling back during "Starting blackout…" cancels; no blackout follows; screens return to mirroring.
  - Row 23: unplug while blacked out (from a mirrored start) → internal restores, no re-mirror attempt.

## Open questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Should turning Blackout off re-mirror the displays we un-mirrored? | Product Manager | 2026-10-20 | **Resolved — yes** (owner decision). Turning Blackout off or cancelling a pending blackout re-mirrors the remembered externals onto the builtin (in-memory topology; master is always the builtin). Automatic restores don't re-mirror. `.forSession` stays as the next-login backstop. |
| Does macOS ever reject `CGConfigureDisplayMirrorOfDisplay(…, kCGNullDirectDisplay)` for an external that is the *master* of a mirror set (built-in mirroring the external)? | macOS Engineer / QA | — | Field case had the built-in as master. Verify the reverse topology on hardware row 20; failure path surfaces the "Couldn't stop screen mirroring…" error, never a dark screen. |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-10-20 | Stop mirroring automatically instead of showing a "turn off Mirror" hint | Users are non-technical; the owner asked for it to be automatic. The error text is kept only as the fallback when un-mirroring fails or times out |
| 2026-10-20 | Use public `CGConfigureDisplayMirrorOfDisplay(id, kCGNullDirectDisplay)` inside a CG configuration transaction | Public, documented API; no new private symbol. Same transaction discipline as Contract A (begin → configure → complete, cancel on failure) |
| 2026-10-20 | Complete with `.forSession`, not `.permanently` | We change the user's mirror setting only for the current session; even if a re-mirror never happens (timeout, unplug, crash), their own preference comes back at next login |
| 2026-10-20 | Don't disable in the same call; wait for the external to become drawable and apply via the guarded `disableInternalDisplay()` | macOS reconfigures asynchronously; the usable-external guard must see a really drawable external. Keeps every existing guard authoritative |
| 2026-10-20 | 15 s timeout on a monotonic clock (`systemUptime`, injectable for tests) | Un-mirroring normally settles in a few seconds; a bound prevents an indefinite "Starting blackout…" state; wall-clock changes can't skew it |
| 2026-10-20 | ~~No re-mirror when Blackout is turned off (for now)~~ — **superseded same day** | Kept scope minimal for v0.1.8; owner then decided the setup should return to how the user had it |
| 2026-10-20 | Switch shows "on" while pending; toggling during pending cancels | Prevents the switch bouncing off-then-on during the un-mirror window; cancelling is the natural reading of flipping it back |
| 2026-10-20 | Re-mirror the externals Sasih un-mirrored when the user turns Blackout off or cancels "Starting blackout…"; master is always the builtin | Owner decision: non-technical users expect their setup back. Un-mirroring only happens when no usable external exists, so the builtin was the sole active display and therefore the mirror master — no topology beyond the external IDs needs remembering |
| 2026-10-20 | Re-mirror only on user intent; clear the memory on unplug emergency restore, wake `.leaveOn`, pending timeout, or when blackout is on/pending again | An automatic restore isn't a "Blackout off" request — re-mirroring behind the user's back (or onto a display that's gone) would be surprising. `.forSession` still restores their preference at next login |
| 2026-10-20 | Re-mirror waits until the builtin is **active** and the externals are still active, retries a failed call, and gives up silently after 15 s (`remirrorTimeout`, monotonic) | The builtin takes a moment to come back after the SkyLight enable; mirroring onto a non-drawable master would fail. A failure is harmless (screens stay extended, nothing goes dark), so no error copy is surfaced |
