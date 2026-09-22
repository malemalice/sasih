# Playbook — Hardware Verification (Manual Matrix)

> Mandatory for any change to the private-API path, lifecycle handling, sleep/wake, reconfiguration callbacks, or safety nets. Unit tests with fakes cannot prove real behaviour (hard rule 4 in `AGENTS.md`).
> Owner: QA Engineer. Never parallelise a matrix run with code changes on the same machine.

## 0. Safety framing (read first)

`SLSConfigureDisplayEnabled` toggles a **software display-enabled flag** inside WindowServer/SkyLight — the same class of call the system itself uses when reconfiguring displays (e.g. plugging in a monitor). It does not touch panel firmware, backlight driver EEPROM, SMC state, or any persistent hardware setting. There is no code path here that can physically damage the display, brick the Mac, or create a state that survives a reboot.

The real risk is **not hardware failure** — it's a *usability* failure: being stuck looking at a dark internal panel with no visible external display and not knowing how to get the picture back. The safety nets exist to prevent that in software, but every one of them must be verified, and the manual out-of-band recovery path below must always exist.

## 1. Preconditions

- Apple Silicon MacBook (M1 or newer), macOS 13+ — the only supported configuration.
- An external display connected (the matrix assumes the normal two-display setup).
- The build under test is the current head (`./build.sh`), launched via `open Sasih.app`.
- For rows 15–16: a 13" M1/M2 MacBook Pro (the only Apple Silicon Touch Bar models) — otherwise mark those rows N/A.

Observe what the app decided while reproducing any failure:

```bash
log stream --predicate 'subsystem == "com.adaptivid.sasih"' --level info
```

## 2. Matrix

Record pass/fail per row, plus macOS version and app build. "Assumed from code" is not a result.

| # | Scenario | Expected result |
|---|---|---|
| 1 | Toggle off with external display connected | Internal panel goes dark; external stays active; keyboard/trackpad/Touch Bar/speakers unaffected |
| 2 | Toggle back on | Internal panel returns, correct resolution/arrangement, no leftover black window/artifact |
| 3 | Unplug external display while internal is off | Internal display **auto-restores within a few seconds**, unprompted |
| 4 | Replug external display after auto-restore | App returns to normal "internal on, external on" state, toggle available again |
| 5 | Quit app normally (menu bar → Quit) while internal is off | Internal display is restored **before** the process exits — never left off |
| 6 | Force-quit app (`kill -9` / Activity Monitor → Force Quit) while internal is off | Internal display restores automatically on next launch, before any UI interaction |
| 7 | Force-quit, then do **not** relaunch the app | Internal display should already be visible immediately after the kill (verifies restore isn't solely gated on relaunch) — if this fails, note it as a known gap, since some designs restore on next launch |
| 8 | Sleep (close external's power / `pmset sleepnow`) while internal is off, then wake | Internal display is off again after wake settles (a few seconds), matching pre-sleep state |
| 9 | Sleep while internal is **on**, then wake | No unexpected state change |
| 10 | Cold boot / full restart with the "off" state persisted from before shutdown | Internal display should NOT be off automatically before the user can see anything on the first boot screen — verify no risk of a black-panel boot with no external display attached at boot time |
| 11 | Toggle off, then immediately toggle on again rapidly (stress the transaction queue) | No crash, ends in correct final state, no orphaned pending-disabled IDs |
| 12 | Launch at Login enabled, restart Mac with external display attached | App launches, previous "off" state is NOT auto-applied without the safety checks re-running first |
| 13 | Attempt toggle off with **no** external display connected | Refused with a visible error/hint, internal display untouched |
| 14 | macOS "Detect Displays" triggered manually while internal is off | State remains stable, no unexpected re-enable or crash |
| 15 | **Auto-Blackout** (added 2026-09-06): toggle off → unplug external (auto-restore) → replug external, preference **on** | Internal display switches back off by itself once the external reconnects; `internalOnIsFallback` reconciliation path exercised |
| 16 | **Auto-Blackout off**: same sequence as row 15 | Internal display stays on after reconnect; no automatic re-disable |
| 17 | **Touch Bar (13" M1/M2 only)**: toggle off, then on | Touch Bar renders normally after the automatic nudge (blank-but-responsive Touch Bar = fail → see `docs/trd/mac-app-blackout/constraints-integrations.md` §5) |
| 18 | **Display sleep with blackout active** (added 2026-09-22): toggle off with external connected, run `pmset displaysleepnow`, wait >10s (backstop ticks), then wake the displays | Blackout survives: internal stays off after wake; no unintended restore happens while the screens are asleep |
| 19 | **Undock / ghost stress** (added 2026-09-22): toggle off with external connected, close the lid, unplug the external, open the lid elsewhere | Internal display restores within a few seconds, even if WindowServer transiently still lists the removed external |
| 20 | **Mirrored external** (added 2026-09-22): mirror the external and the built-in, then attempt to toggle off | Never leaves a black-only setup: blackout either applies while the mirrored image stays drawable, or the toggle is refused with the connect-a-display hint — record which |

## 3. Which rows a change requires

| Change touches | Minimum rows |
|---|---|
| `DisplayManager` / guards / state diff / persisted keys | 1–13 (all core toggle + safety paths) |
| Reconfiguration callback / backstop timer | 3, 4, 14 (+ 1, 2) |
| Sleep/wake handling | 8, 9, 18 |
| Restore-on-launch / restore-before-quit | 5, 6, 7, 10, 12 |
| Launch at Login (`SMAppService`) | 12 |
| Auto-Blackout preference | 15, 16 (+ 3, 4) |
| External-presence predicate (usable/drawable external, screen-sleep deferral) | 1–4, 8, 9, 13, 15, 16, 18, 19, 20 |
| Touch Bar recovery | 17 (+ 1, 2) |
| Menu bar UI only (copy/layout) | 1, 2, 13 visual checks |
| Private SkyLight symbol/transaction | 1–20 — all of them |

## 4. Compatibility re-verification

Private-API behaviour across macOS point releases is not guaranteed — that's exactly the kind of thing that silently changes.

- Run the full matrix on the machine's current macOS before first daily use, and again after **any** macOS upgrade (minor or major) on that machine, before trusting it again.
- On a second machine or fresh OS install: re-run at minimum rows 1–9 and 13.

## 5. Manual recovery path (must exist, independent of the app)

Confirm this once (deliberately reboot while the internal display is off) so it is a known-good fallback, not an assumption:

1. **Reboot the Mac** (hold the power button if unresponsive). The disable is a WindowServer-session-only flag (see §0), so a reboot always clears it.
2. If rebooting is not immediately possible: connect via Screen Sharing / remote access from another device and trigger enable / quit the app.

## 6. Sign-off template

Copy into the release checklist or exec-plan:

```
Hardware verification — <app version> on <macOS version> (<build>) — <date>
Matrix: 1..17 — pass/fail notes for any deviation
N/A rows + reason (e.g. no Touch Bar hardware):
Recovery path re-confirmed: yes/no
Tester (QA): <name/agent> — sign-off: <result>
```
