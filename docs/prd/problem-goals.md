# Problem, Goal, Non-Goals, Success Criteria

## Summary

Sasih is a macOS menu-bar utility that turns off a MacBook's built-in display on demand — like closing the lid (clamshell mode), but the lid stays open. Keyboard, trackpad, Touch Bar, and speakers keep working normally; only the internal panel goes dark. Requires an external display to be connected (macOS will not allow the only display to be disabled).

## Problem

Real clamshell mode requires closing the lid, which:

- Disables the built-in keyboard, trackpad, and Touch Bar (must use external peripherals).
- Requires an external keyboard/mouse/stand setup for some users to even wake the Mac.

Users who want a single-monitor-only workflow, but still want to use the built-in keyboard/trackpad/speakers, have no first-party way to turn off just the internal screen while the lid is open. Existing tools that offer this (Lunar, BetterDisplay) bundle it inside large, paid, closed-source apps with unrelated feature sets.

## Goal

A small, free, single-purpose, direct-distributed app that does one thing well: toggle the internal display off/on safely, with sane defaults and no way to strand the user with a black screen and no way back.

## Non-goals (MVP)

- Working with the MacBook as the *only* display (no external monitor) — explicitly not supported in v1; internal-only software blackout overlay is a possible future mode, not built now.
- Multi-external-display "solo mode" (choose exactly one of N displays) — a Lunar/BetterDisplay-style feature, not needed for this use case.
- Global hotkey — nice-to-have, not MVP.
- Any Mac App Store distribution — ruled out; direct notarized DMG only.
- Windows/other OS — N/A.
- Non-Apple-Silicon support — out of scope; see `trd/mac-app-blackout/constraints-integrations.md`.

## Success criteria

- Toggling off/on works reliably and reversibly across normal daily use (sleep/wake, display connect/disconnect, app quit).
- Zero incidents of "stuck with internal display off and no way to see anything" during real usage.
- No perceptible impact on keyboard/trackpad/Touch Bar/speaker behavior.
