# Stack & Architecture — mac-app-blackout (Sasih)

> Migrated from the former repo-root `TRD.md` §1, §3.

## 1. Overview

Menu-bar-only macOS app (no Dock icon — `LSUIElement = true`) built in Swift 6 / SwiftPM, SwiftUI `MenuBarExtra` shell over an AppKit `NSApplicationDelegate`, distributed as a signed DMG outside the Mac App Store. Core mechanism: call a private CoreGraphics/SkyLight symbol to enable/disable a display within a standard `CGBeginDisplayConfiguration` transaction.

## 2. Build system

| Item | Value |
|---|---|
| Toolchain | Swift 6.0 (`swift-tools-version: 6.0`), SwiftPM |
| Platform | macOS 13.0+ (`Package.swift` `.macOS(.v13)`, `LSMinimumSystemVersion 13.0`) |
| Architectures | Apple Silicon only (arm64) |
| Third-party deps | **None** — SwiftPM `dependencies: []` |
| Xcode requirement | None — builds with Command Line Tools only (see `test.sh`/`build.sh` search-path flags) |

## 3. Targets

| Target | Type | Path | Role |
|---|---|---|---|
| `SasihCore` | library | `Sources/SasihCore` | Pure, testable display logic; no AppKit/UI; all hardware access behind injected protocols |
| `SasihApp` | executable | `Sources/SasihApp` | Menu-bar app shell, SwiftUI UI, lifecycle & safety-net wiring |
| `SasihSpike` | executable | `Sources/SasihSpike` | Throwaway CLI used for the original private-API spike; not shipped |
| `SasihCoreTests` | test | `Tests/SasihCoreTests` | Unit tests for core logic |
| `SasihAppTests` | test | `Tests/SasihAppTests` | Unit tests for view model + Touch Bar recovery |

## 4. Module layout

```
Sources/SasihCore/
  DisplayManager.swift            // single source of truth for display on/off; safety nets
  DisplayGuards.swift             // pure guard predicates (external present, last active display)
  DisplayStateDiff.swift          // minimal change-list computation (pure)
  DisplayIDStore.swift            // persistence: UserDefaults + ~/.sasih_internal_display_id backup
  DisplayInfoProvider.swift       // CGDisplayInfoProvider: online + active (drawable) IDs, isBuiltin, usable-external count
  SleepWakeDecision.swift         // pure wake-action decision (reapplyOff / leaveOn / doNothing)
  VersionComparison.swift         // semver compare for UpdateChecker
  PrivateAPI/
    DisplayConfigSymbolResolver.swift  // dlopen/dlsym + SLS→CGS fallback, SymbolLookup protocol
    DisplayConfiguring.swift           // DisplayConfiguring protocol + real CG transaction impl

Sources/SasihApp/
  SasihApp.swift                  // @main, MenuBarExtra scene, MenuBarIcon (template image)
  AppDelegate.swift               // lifecycle, reconfiguration callback, sleep/wake observers, backstop timer
  DisplayStateViewModel.swift     // observable state bridging DisplayManager ↔ SwiftUI
  MenuBarView.swift               // menu UI + MenuRow component
  LaunchAtLogin.swift             // SMAppService.mainApp wrapper
  TouchBarRecovery.swift          // pmset/caffeinate nudge for Touch Bar Macs
  UpdateChecker.swift             // GitHub Releases API check
```

## 5. Architecture rules (do not violate)

1. **`SasihCore` never imports AppKit/SwiftUI and never touches real hardware directly.** All hardware interaction is behind `DisplayConfiguring`, `DisplayInfoProviding`, `DisplayIDPersisting`, and `SymbolLookup`, injected via `DisplayManager.init`. This is what makes the hard logic unit-testable (see `Tests/SasihCoreTests`).
2. **`DisplayManager` is the single source of truth for "is the internal display off"** (`isInternalDisplayOff`). UI reads it through `DisplayStateViewModel`; nothing else computes it.
3. **All UI mutations go through `DisplayStateViewModel`, on `@MainActor`.** `AppDelegate` hops to `@MainActor` before touching manager or view model from callbacks/timers.
4. **`PrivateAPIDisplayConfigurer`** wraps the resolved private symbol (see `api-contracts/`) inside the *public* `CGBeginDisplayConfiguration` → symbol call → `CGCompleteDisplayConfiguration(.forSession)` transaction; on failure it calls `CGCancelDisplayConfiguration`.
5. **Every display-state decision is logged to the unified log** (`os.Logger`, subsystem `com.adaptivid.sasih`) with `privacy: .public` on every interpolated value — the timing-dependent paths cannot be reproduced under test, so logging is the only observability.

## 6. Component responsibilities — DisplayManager

1. Resolve the internal display's `CGDirectDisplayID` (via `infoProvider.isBuiltin`) and cache it — must survive process restarts, since once disabled the display won't appear in `NSScreen.screens` to re-identify. Persisted to `UserDefaults` *and* a backup file (belt-and-suspenders).
2. `disableInternalDisplay()` — guarded: if the panel is already absent from the online list, records the off-state and returns success without a hardware call (the private call would fail the whole transaction on an already-disabled display); otherwise refuses unless at least one **usable** external is present (online *and* drawable — see `usableExternalDisplayIDs()`) and refuses when the disable would leave no other active display. A stale/ghost entry in the online list is not a usable external.
3. `enableInternalDisplay()` — always safe to call; used by every restore path.
4. `performEmergencyCheckIfNeeded(screensAreAsleep:)` — the safety-net reconciliation: defers entirely while the screens are in display sleep (no display is drawable then); first, if the recorded on-state disagrees with reality (panel absent from the online list and either no usable external is present or the internal-on was a fallback) → record it off; then if internal is off and no usable external is present → restore; then if internal is on only as a fallback and a usable external has appeared → re-apply off, subject to the `Auto-Blackout` preference.
5. `restoreOnLaunchIfNeeded()` (crash/force-quit recovery, before any UI), `restoreBeforeQuit()` (normal quit), `handleWake()` (sleep/wake restoration via the pure `SleepWakeDecision`; the `leaveOn` path verifies the panel is actually back online and explicitly restores it if macOS did not, recording "off" when that restore fails so the safety nets keep retrying).

## 7. Runtime state model

```
enum DisplayState { enabled, disabled }   // conceptual; surfaced as DisplayManager.isInternalDisplayOff: Bool
```

Kept minimal for MVP — no multi-display "solo mode," just binary internal on/off. Internal flags:

- `internalOnIsFallback: Bool` — internal is on only because no external was present at decision time, not by user choice. In-memory only; gates auto-revert.
- `cachedInternalDisplayID` — in-memory copy of the persisted ID.

## 8. Event wiring (AppDelegate)

| Event | Handler | Action |
|---|---|---|
| Launch | `applicationDidFinishLaunching` | `restoreOnLaunchIfNeeded()` → `viewModel.refresh()` → register callback/observers → start 10s backstop timer |
| Display reconfiguration | `CGDisplayRegisterReconfigurationCallback` | Ignore `.beginConfigurationFlag` events; on settled events → `handleDisplayReconfiguration()` |
| Backstop timer (10s) | `Timer` | `handleDisplayReconfiguration()` in case a callback was missed; defers while the screens are asleep |
| System wake | `NSWorkspace.didWakeNotification` | Clears the screens-asleep flag, waits 2s for macOS's own reconfiguration to settle, then `handleWake()`. `handleWake()` verifies the panel is online and restores it explicitly if macOS didn't (see `docs/erd/relationships.md`). Deliberately does **not** run the Touch Bar nudge (it synthesizes display sleep/wake and would race our own callbacks). |
| Screens sleep / wake (display sleep) | `screensDidSleepNotification` / `screensDidWakeNotification` | Tracks `screensAreAsleep`: while asleep, emergency checks do nothing (display sleep makes every display non-drawable, which must not read as "external gone" and cancel blackout); on wake, re-runs the check after 1s |
| Will sleep / screen lock / unlock | `willSleepNotification`, `com.apple.screenIsLocked/Unlocked` | Diagnostics only — logging, never state changes |
| Normal quit | `applicationWillTerminate` | `restoreBeforeQuit()` |
