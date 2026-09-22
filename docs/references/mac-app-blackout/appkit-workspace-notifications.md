# AppKit Workspace & Notification Reference

> Repo: mac-app-blackout
> Version: macOS 13+
> Source: Apple AppKit docs (`NSWorkspace`, `DistributedNotificationCenter`, `NSAlert`, `NSApplication`)
> Last updated: 2026-09-22

## Overview

AppKit supplies the app's lifecycle hooks (delegate), the sleep/wake signal, the diagnostic lock/unlock observers, the About panel, and the update alerts.

## Key APIs used in this repo

| API | Used in | Purpose |
|---|---|---|
| `NSApplicationDelegate.applicationDidFinishLaunching` | `AppDelegate` | Crash recovery **before** UI; register callback/observers/timer |
| `NSApplicationDelegate.applicationWillTerminate` | `AppDelegate` | `restoreBeforeQuit()` — never exit with the panel off |
| `NSWorkspace.shared.notificationCenter` `.didWakeNotification` | `AppDelegate` | Wait 2s, then `displayManager.handleWake()` |
| `NSWorkspace.shared.notificationCenter` `.willSleepNotification` | `AppDelegate` | Diagnostics only (log), never state changes |
| `DistributedNotificationCenter` `com.apple.screenIsLocked` / `screenIsUnlocked` | `AppDelegate` | Diagnostics only |
| `NSApplication.shared.terminate(_:)` | `MenuBarView` | Quit menu row |
| `NSApplication.orderFrontStandardAboutPanel(options:)` | `MenuBarView` | About panel with credits |
| `NSAlert` | `MenuBarView` | Update-check result alerts only |
| `NSApplication.activate(ignoringOtherApps:)` | `MenuBarView` | Bring alerts/About forward from a background app |

## Common patterns

- Diagnostic observers stay strictly logging-only. If you're tempted to add state logic to the lock/unlock/will-sleep handlers, that is a behaviour change — it belongs in an exec-plan, not a drive-by edit (see the comment in `registerDiagnosticObservers`).
- Wake handling is delayed by 2 seconds because macOS re-enables all displays as part of its own wake reconfiguration; acting immediately fights the system.
- `LSUIElement = true` means no Dock icon and no automatic app activation — any user-visible panel/alert must call `activate(ignoringOtherApps:)` first.

## Gotchas

- `didWakeNotification` fires for full *system* sleep only — **not** for plain display sleep. Do not assume it covers `pmset displaysleepnow` (which `TouchBarRecovery` itself triggers — a reason the nudge is intentionally absent from the wake path to avoid a feedback loop).
- Observers are registered on `NSWorkspace.shared.notificationCenter`, not `NotificationCenter.default`.
- Alerts from an `LSUIElement` app do not steal focus by default; without the explicit activation call they can appear behind other windows.

## Do not use

- `NSApp.hide`/`NSApplication.hide` tricks to fake a blackout (that would hide windows, not disable the display — and break the app's core promise).
- Any sleep/wake state decision inside the diagnostic handlers.
