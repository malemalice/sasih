# Exec Plan: ghost-external-stranding

> Status: [ ] Draft | [x] In Progress | [ ] Blocked | [ ] Complete
> Created: 2026-09-22
> Repo: mac-app-blackout (single-repo workspace)
> Agent(s): macOS Engineer (QA hardware matrix handed over at the end)
> Touches: `Sources/SasihCore/DisplayInfoProvider.swift`, `DisplayGuards.swift`, `DisplayManager.swift`,
> `Sources/SasihApp/AppDelegate.swift`, `DisplayStateViewModel.swift`, tests, canonical docs
>
> **Code + tests complete 2026-09-22; awaiting QA hardware matrix (rows 18–20 + regression rows).**

## Goal

Close the remaining "never strand the user" hole: every blackout/restore decision currently
trusts `CGGetOnlineDisplayList` as proof that "an external display is present", but the online
list reports connectability, not drawability — stale/ghost or indirect-mirror entries can keep
it non-zero while the user has no visible display, which blocks the emergency restore and lets
wake/auto-revert black out the built-in panel with nothing to fall back to.

## Scope

**In scope**

- Define "usable external" for all safety decisions as **drawable** — `CGDisplayIsActive`
  (connected + awake + drawable; SDK header `CGDisplayConfiguration.h:282`) — not merely online.
- Use that predicate in: `disableInternalDisplay()` guard, `performEmergencyCheckIfNeeded()`
  (reconciliation, restore gate, auto-revert), `handleWake()` external-presence check, and the
  UI's `hasExternalDisplay`.
- Suppress emergency checks while the screens are asleep (`NSWorkspace.screensDidSleep/Wake`),
  so the display-sleep state (no drawable display at all) cannot be mistaken for "external gone"
  and silently cancel blackout.
- Log `activeDisplayIDs` + usable counts alongside the online list at every decision point.

**Out of scope**

- Replacing the SkyLight transaction layer or the persisted-key contract (unchanged).
- Handling a stale display that still reports *active/drawable* — indistinguishable via public
  CG queries; recorded as residual debt (TD-011).
- Touch Bar path, release pipeline.

## Approach

1. `DisplayInfoProviding` gains `activeDisplayIDs()`; a default extension composes
   `usableExternalDisplayIDs()` = online ∧ ¬builtin ∧ active. `CGDisplayInfoProvider` implements
   it with `CGGetActiveDisplayList` (reusing the synthetic-placeholder filter).
2. Guards keep their shape; `DisplayGuards.canDisableInternal` is renamed to take the usable
   count so no caller can pass the online count by accident. `isLastActiveDisplay` now receives
   the *active* count, which makes it a real second net again (it was effectively dead while it
   received the online count).
3. Restore gate becomes `usableExternalCount == 0`, so a ghost/mirror-only list restores the
   panel. Auto-revert and wake-reapply require `usableExternalCount > 0`, so they cannot black
   out the panel on a non-drawable entry.
4. `performEmergencyCheckIfNeeded(screensAreAsleep:)` skips all action while screens sleep;
   `AppDelegate` tracks the flag from `screensDidSleep/WakeNotification` and re-checks shortly
   after screens wake. This is what preserves blackout across ordinary display sleep instead of
   treating it as "no external present".
5. Alternatives considered:
   - `CGDisplayIsAsleep` as the discriminator — rejected: active excludes asleep displays
     (header: "connected, awake, and available for drawing"), so a sleeping real external would
     trigger a false restore on every display-sleep cycle; the screens-asleep suppression is the
     accurate signal.
   - Treating mirror-set membership as usable — rejected: hardware mirror slaves can be online
     but not drawable; the safe direction is to refuse blackout when no external is drawable.
     At least the drawable member of a mirror set remains active, so mirroring is best-effort but
     never black-only.

## Steps

1. [x] Exec-plan written.
2. [x] `DisplayInfoProvider` + `DisplayGuards` changes.
3. [x] `DisplayManager` decision points.
4. [x] `AppDelegate` screens-sleep tracking + `DisplayStateViewModel`.
5. [x] Fakes + regression tests (8 new; 68 total).
6. [x] `./test.sh` green; `./build.sh` clean (no warnings).
7. [x] Canonical docs updated in the same change.
8. [ ] QA hardware matrix run (rows 1–4, 8, 9, 13, 15, 16, 18, 19, 20) on the new build.

## Success criteria

- `./test.sh` fully green, including new regression tests:
  - disable refused when the only listed external is not active (ghost);
  - emergency restore fires when the only listed external is not active;
  - reconciliation heals recorded-on/panel-off divergence while a non-usable external is listed;
  - auto-revert and wake-reapply do not act on non-active externals;
  - emergency check does nothing while `screensAreAsleep == true`.
- Hardware matrix (from `docs/playbooks/hardware-verification.md`) run by QA on real hardware:
  - rows 1–4, 8, 9, 13, 15, 16 (existing safety/toggle paths — the predicate change touches them);
  - row 18 (display sleep while blackout active → blackout survives, no unintended restore);
  - row 19 (undock + lid open elsewhere → internal restores within seconds);
  - row 20 (mirrored external → never black-only).
- No new dependency; `SasihCore` stays UI-free; no safety net removed (the screens-asleep skip
  is a suppression with an explicit wake re-check, not a removal).

## Open questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Does a ghost entry ever report `active == true` on this macOS build? | QA / macOS Engineer | matrix run | monitor unified log during row 19; record in TD-011 if observed |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-22 | Usable external = `CGDisplayIsActive` (drawable) | Online list reports connectability; non-drawable entries (ghosts, indirect mirrors) blocked the emergency restore and drove wake re-apply. Field evidence: 987× `refused — would be the last active display` loop and the 2026-09-21 forced-reboot incident. |
| 2026-09-22 | Emergency checks suppressed while screens are asleep, re-checked on `screensDidWake` | Prevents display sleep from being read as "external gone" (which would cancel blackout) while keeping the restore live the moment screens wake. |
| 2026-09-22 | **Hardware matrix waived by owner** for v0.1.5; shipped unsigned (no valid Developer ID cert on the build machine) | Owner explicitly approved shipping now ("ship now, waive matrix"). Matrix rows 18–20 must still be run before the next release; TD-011 stays open. |

## Release checklist (v0.1.5, 2026-09-22)

- [x] Owner approval obtained (explicit, 2026-09-22)
- [x] `./test.sh` green (68 tests)
- [ ] Hardware matrix complete on this build — **waived by owner, 2026-09-22** (rows 18–20 pending)
- [x] Both Info.plist version keys bumped; convention-consistent commit
- [ ] Signed with `$SASIH_SIGNING_IDENTITY` — **not possible**: only expired Apple Development certs on the build machine; shipped adhoc-signed, matching v0.1.4 practice
- [ ] DMG notarized (`--wait`), stapled, `spctl` accepted — **not possible** without a Developer ID cert; README's right-click → Open flow applies
- [x] GitHub Release `v0.1.5` published, full release, DMG attached
- [x] `releases/latest` returns the new tag
- [x] Docs updated (stack-architecture, relationships, entities, decisions, matrix, TD-011)
