# Technical Requirements Document — Sasih

## 1. Overview
Menu-bar-only macOS app (no Dock icon) built in Swift/SwiftUI or AppKit, distributed as a notarized DMG outside the Mac App Store. Core mechanism: call a private CoreGraphics/SkyLight symbol to enable/disable a display within a standard `CGBeginDisplayConfiguration` transaction.

## 2. Core mechanism

### 2.1 The API
- Symbol: `SLSConfigureDisplayEnabled` (primary), fallback to older name `CGSConfigureDisplayEnabled`.
- Location: private framework `/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight`.
- Resolved at runtime via `dlopen` + `dlsym` (not linked at compile time — no header exists; this is expected for a private symbol).
- Signature (C calling convention):
  ```swift
  typealias ConfigureDisplayEnabledFn = @convention(c) (OpaquePointer?, CGDirectDisplayID, Int32) -> CGError
  ```
- Usage pattern (wraps the private call in *public* CG transaction APIs):
  ```swift
  var configRef: CGDisplayConfigRef?
  CGBeginDisplayConfiguration(&configRef)
  configureDisplayEnabled(configRef, displayID, 0)   // 0 = disable, 1 = enable
  CGCompleteDisplayConfiguration(configRef, .forSession)
  ```

### 2.2 Why this API and not the "correct" one
macOS's real clamshell mode is driven by `powerd` calling `SLSDisplayPowerControlClient.requestStateChange(_:error:)` with `kSLSDisplayControlRequestClamshellState`. That call requires the `com.apple.private.SkyLight.displaypowercontrol` entitlement, which AMFI refuses to grant to any non-Apple-signed binary — confirmed via independent reverse-engineering research (Alin Panaitiu / Lunar author, public blog post). This path is a dead end for a third-party app, entitlement or no entitlement, SIP on or off.

`SLSConfigureDisplayEnabled` does not require that entitlement — it's a lower-level "remove this display from the system" call (closer to a software disconnect than a true power-state transition), reachable via plain `dlopen`/`dlsym`. This is confirmed working via an independent open-source reference implementation (see §2.3).

### 2.3 Reference implementation
[RonaldPark89/InternalDisplayOff](https://github.com/RonaldPark89/InternalDisplayOff) — public GitHub repo, no LICENSE file (treat as read-only reference for the *technique and safety-net design*, do not copy code verbatim). Confirms:
- The exact symbol/signature above works on real hardware.
- macOS fires one `CGDisplayReconfigurationCallback` event per disabled display, not one per transaction — state tracking must account for this.
- Calling `SLSConfigureDisplayEnabled` on an already-disabled display fails the entire transaction — always diff current vs. target state before building the change list.

### 2.4 Platform constraint
Apple Silicon only, macOS 13 (Ventura) or later. Reasoning: this is the same generation/constraint that Lunar's BlackOut-via-disconnect feature targets (per public changelog), and is the version the reference implementation was built/tested against. **Decision needed:** confirm minimum OS version once local dev machine's macOS version is known; do not attempt to support Intel Macs or pre-Ventura — different display stack internals, unverified and out of scope.

## 3. Architecture

### 3.1 Components
- **App shell**: SwiftUI `MenuBarExtra` (macOS 13+, avoids manual `NSStatusItem` plumbing) or AppKit `NSStatusItem` if more popover control is needed. No Dock icon (`LSUIElement = true` in Info.plist).
- **DisplayManager** (core singleton): owns all interaction with the private API, display state, and safety nets. Single source of truth for "is internal display off."
- **LaunchAtLogin**: `SMAppService.mainApp` (modern API, macOS 13+) for login-item registration.

### 3.2 DisplayManager responsibilities
1. Resolve internal display's `CGDirectDisplayID` (via `CGDisplayIsBuiltin`) and cache it — must survive process restarts, since once disabled the display won't appear in `NSScreen.screens` to re-identify.
   - Persist to `UserDefaults` and/or a small file (belt-and-suspenders — reference impl does both).
2. `disableInternalDisplay()` — guarded: refuse unless `externalDisplayCount > 0`.
3. `enableInternalDisplay()` — always safe to call; used by every restore path.
4. Track `pendingDisabledIDs` while the disable transaction is in flight, to prevent the reconfiguration-notification flurry from causing incorrect state.

### 3.3 Safety nets (non-negotiable — this is the whole point of the app being trustworthy)
- **No external displays detected while internal is off → force-restore immediately.** Triggered from both the `CGDisplayReconfigurationCallback` (external unplugged) and a periodic background timer (~10s) as a backstop in case the callback is missed.
- **App quits (normal exit)** → restore internal display in the quit handler before the process exits.
- **App crashes / force-quit** → on next launch, check `UserDefaults`/backup file for "was disabled" state; if so, immediately issue the enable call before any UI is shown.
- **Sleep/wake** → macOS re-enables all displays on wake as part of its own reconfiguration. Record "was off before sleep" on `NSWorkspace.willSleepNotification`; on `didWakeNotification`, wait ~2s for the system to settle, then re-apply the disabled state if it was active and an external display is still present.
- **Never disable the last remaining active display.** Explicit guard, independent of the "external count > 0" check, as defense in depth.

### 3.4 State model
```
enum DisplayState { enabled, disabled }
```
Kept minimal for MVP — no multi-display "solo mode," just binary internal on/off. `DisplayManager.isInternalDisplayOff: Bool` published/observable for menu-bar UI binding.

## 4. Distribution
- Direct download, notarized + signed with a Developer ID Application certificate (not Mac App Store — private API usage is an automatic App Review rejection).
- Standard `codesign` + `notarytool` pipeline; DMG packaging.
- Requires an active Apple Developer Program membership for the Developer ID cert (assumption — confirm user already has one before build).

## 5. Entitlements / sandboxing
- App runs **unsandboxed** (App Sandbox is incompatible with `dlopen`-ing a private system framework in practice, and irrelevant outside the App Store anyway).
- No special entitlements required beyond standard code-signing — this is the key advantage of `SLSConfigureDisplayEnabled` over the clamshell-state XPC approach (§2.2).

## 6. Risks & mitigations
| Risk | Mitigation |
|---|---|
| Private symbol renamed/removed in a future macOS release | Try both `SLSConfigureDisplayEnabled` and `CGSConfigureDisplayEnabled` by name at runtime; fail gracefully (visible error in menu, no silent black screen) if neither resolves. |
| Internal display ID lookup fails after disable (can no longer query `NSScreen` for it) | Cache the ID persistently *before* disabling, from multiple sources (UserDefaults + file) per §3.1. |
| User left with no visible display | All safety nets in §3.3; this is the top-priority correctness requirement of the whole app. |
| App Store rejection if ever submitted by mistake | Non-issue — direct distribution only, documented in PRD/TRD as a permanent decision, not a v1-only constraint. |

## 7. Build plan (spike-first, matches earlier grooming)
1. **Spike**: throwaway CLI/single-file test — call `dlopen`/`dlsym` for `SLSConfigureDisplayEnabled`, toggle the internal panel off/on on the actual dev machine, confirm it works on the target macOS version before writing any app shell.
2. **DisplayManager**: build the full component per §3.2–3.3, including all safety nets, before any UI.
3. **Menu-bar shell**: minimal toggle UI wired to DisplayManager.
4. **Launch at Login** toggle.
5. **Sign, notarize, package DMG.**
6. **Real-world dogfood**: daily use for a stretch (sleep/wake cycles, unplug/replug external monitor, force-quit) before considering it done — this is the kind of correctness that unit tests won't catch.

## 8. Verification & testing plan

### 8.0 Hardware-safety framing (read this first)
`SLSConfigureDisplayEnabled` toggles a **software display-enabled flag** inside WindowServer/SkyLight — the same class of call the system itself uses when reconfiguring displays (e.g. plugging in a monitor). It does not touch panel firmware, backlight driver EEPROM, SMC state, or any persistent hardware setting. There is no code path here that can physically damage the display, brick the Mac, or create a state that survives a reboot.

The real risk is **not hardware failure** — it's a *usability* failure: being stuck looking at a dark internal panel with no visible external display and not knowing how to get the picture back. Section 3.3's safety nets exist to prevent that in software, but every one of them must be verified, and there must always be a manual, out-of-band recovery path that doesn't depend on the app's own code working correctly. That recovery path (§8.4) is worth confirming before the first real test, not after.

### 8.1 Unit tests (automatable, run in CI on every commit)
Pure-logic pieces of `DisplayManager` that don't require touching real display hardware — extract them so they're testable in isolation from `dlopen`/`CGDisplayConfigRef`:
- **State-diff logic**: given a current display set + a target state, produces the correct minimal change list (and never re-issues a change for a display already in the target state — this specific bug is called out in the reference implementation, §2.3).
- **Guard conditions**: `disableInternalDisplay()` refuses when `externalDisplayCount == 0`; never allows disabling the last active display; both as isolated pure functions taking state as input, not reading live `NSScreen`.
- **ID persistence round-trip**: save → simulate process restart → load returns the same `CGDirectDisplayID`, across both storage paths (`UserDefaults` and backup file), including the case where one is missing/corrupt and the other must be used.
- **Sleep/wake decision logic**: "was off before sleep" flag correctly gates whether wake re-applies the disabled state.
- **Symbol-resolution fallback**: given a stub `dlsym` that fails for `SLSConfigureDisplayEnabled` but succeeds for `CGSConfigureDisplayEnabled`, the fallback is used; given both failing, the manager reports "unavailable" rather than crashing or silently no-oping.

Target: these run with `swift test` / XCTest, no display hardware or manual steps involved, fast enough to run on every commit.

### 8.2 Functional / integration tests (require real hardware — cannot be CI-automated)
No CI runner has a physical external display attached, so this tier is a **manual test matrix**, run before every release and after any change to `DisplayManager` or its notification handling. Each row must be physically verified, not assumed from code review:

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
| 13 | Attempt toggle off with **no** external display connected | Refused with a visible error/toast, internal display untouched |
| 14 | macOS "Detect Displays" triggered manually while internal is off | State remains stable, no unexpected re-enable or crash |

Each scenario gets a pass/fail note per macOS version tested (see §8.3) and per release build.

### 8.3 Compatibility verification
- Since §2.4 scopes this to Apple Silicon + macOS 13 (Ventura) or later, run the full §8.2 matrix at minimum on the actual dev machine's current macOS version before first internal use, and again after any macOS upgrade (minor or major) on that machine before trusting it again — private-API behavior across macOS point releases is not guaranteed and is exactly the kind of thing that silently changes.
- If/when used on a second machine or after a macOS upgrade, re-run at minimum scenarios 1–8 and 13 (the core toggle + safety-net paths) before considering it verified there.

### 8.4 Manual recovery path (must exist and be documented, independent of the app)
Confirm and document, before relying on this app day-to-day, at least one way to get the internal display back **without the app's help**, for the case where all software safety nets somehow fail simultaneously:
- Reboot the Mac (hold power button if unresponsive) — since the disable is a WindowServer-session-only flag, not a persistent setting (§8.0), a reboot always clears it.
- If a reboot is not immediately possible: connect via screen sharing / remote access from another device to quit the app or trigger `enableInternalDisplay()` remotely, if remote access is pre-configured.
This should be verified once (deliberately reboot while internal is off) so it's a known-good fallback, not an assumption.

### 8.5 Pre-release checklist
1. All unit tests (§8.1) pass.
2. Full manual matrix (§8.2) run and passed on the target macOS version.
3. Recovery path (§8.4) re-confirmed still works.
4. Dogfood period per Build Plan §7 step 6 completed with zero unrecovered black-screen incidents.

## 9. Explicitly not building (see PRD §6 for product-level scope cuts)
- Software blackout overlay fallback for no-external-display case.
- Multi-display solo-mode.
- Global hotkey.
