# Product Requirements Document — Sasih

## 1. Summary
Sasih is a macOS menu-bar utility that turns off a MacBook's built-in display on demand — like closing the lid (clamshell mode), but the lid stays open. Keyboard, trackpad, Touch Bar, and speakers keep working normally; only the internal panel goes dark. Requires an external display to be connected (macOS will not allow the only display to be disabled).

## 2. Problem
Real clamshell mode requires closing the lid, which:
- Disables the built-in keyboard, trackpad, and Touch Bar (must use external peripherals).
- Requires an external keyboard/mouse/stand setup for some users to even wake the Mac.

Users who want a single-monitor-only workflow, but still want to use the built-in keyboard/trackpad/speakers, have no first-party way to turn off just the internal screen while the lid is open. Existing tools that offer this (Lunar, BetterDisplay) bundle it inside large, paid, closed-source apps with unrelated feature sets.

## 3. Goal
A small, free, single-purpose, direct-distributed app that does one thing well: toggle the internal display off/on safely, with sane defaults and no way to strand the user with a black screen and no way back.

## 4. Target user
The person building and using it — a developer/power user with a MacBook connected to an external monitor, who wants the internal panel dark to save battery/reduce heat/light without touching the lid.

## 5. User stories (MVP)
1. As a user, I can click a menu-bar icon and toggle "Turn off built-in display" on or off.
2. As a user, if I unplug my external display while the internal one is off, the internal display automatically turns back on — I am never left with zero active displays.
3. As a user, if the app crashes or is force-quit while the internal display is off, it is restored automatically (on next launch, or via a background safety check).
4. As a user, if I quit the app normally, the internal display is restored before it exits.
5. As a user, I can enable "Launch at Login" so this is always available without manual setup.
6. As a user, my keyboard, trackpad, Touch Bar, and speakers continue to work exactly as before — no behavior change is expected or acceptable here.
7. As a user, after my Mac sleeps and wakes, my last chosen state (off/on) is restored automatically.

## 6. Out of scope (MVP)
- Working with the MacBook as the *only* display (no external monitor) — explicitly not supported in v1; internal-only software blackout overlay is a possible future mode, not built now.
- Multi-external-display "solo mode" (choose exactly one of N displays) — a Lunar/BetterDisplay-style feature, not needed for this use case.
- Global hotkey — nice-to-have, not MVP.
- Any Mac App Store distribution — ruled out; direct notarized DMG only.
- Windows/other OS — N/A.
- Non-Apple-Silicon support — out of scope; see TRD for why.

## 7. Success criteria
- Toggling off/on works reliably and reversibly across normal daily use (sleep/wake, display connect/disconnect, app quit).
- Zero incidents of "stuck with internal display off and no way to see anything" during real usage.
- No perceptible impact on keyboard/trackpad/Touch Bar/speaker behavior.

## 8. Risks (product-level; see TRD for technical detail)
- The mechanism relies on an undocumented private macOS API. Apple could change or remove it in a future macOS release, breaking the app until updated. Mitigated by: no other viable approach exists for this feature (confirmed via reference implementations from other shipping apps); accept and monitor across macOS updates.
- Because it uses a private API, this app can never ship on the Mac App Store — acceptable, already decided (direct distribution).
- **Touch Bar (on the 13" M1/M2 MacBook Pro, the only Apple Silicon Touch Bar models) can go blank — though still touch-responsive — after a disable→enable cycle.** Previously required a full logout/login to fix; now mitigated automatically in-app via a display sleep/wake nudge triggered right after re-enabling the internal display (see TRD §6 for detail and how it was verified). User story 6 is met in practice, though the underlying WindowServer-level cause is still unconfirmed — treat this as a working mitigation, not a guaranteed-permanent fix.

## 9. Open questions
- Minimum macOS version to support (mechanism confirmed working on Apple Silicon + macOS 13/Ventura and later — see TRD).
- Whether to eventually add a software-blackout fallback mode for the no-external-display case.
