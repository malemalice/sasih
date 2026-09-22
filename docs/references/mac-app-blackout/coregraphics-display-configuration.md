# CoreGraphics Display Configuration Reference

> Repo: mac-app-blackout
> Version: macOS 13+ SDK (`import CoreGraphics`)
> Source: Apple CoreGraphics docs (CGDisplayConfiguration, CGDisplayStream-lifecycle notifications)
> Last updated: 2026-09-22

## Overview

Public APIs used to enumerate displays, identify the built-in one, observe reconfiguration, and wrap the private enable/disable call in a valid transaction.

## Key APIs used in this repo

| API | Used in | Notes |
|---|---|---|
| `CGBeginDisplayConfiguration(_:)` | `PrivateAPIDisplayConfigurer.setDisplay` | Returns `CGError`; must succeed before calling the private symbol |
| `CGCompleteDisplayConfiguration(_:_:)` with `.forSession` | same | Session-scoped — deliberately not permanent |
| `CGCancelDisplayConfiguration(_:)` | same | Called on any failure path after a successful begin |
| `CGDisplayIsBuiltin(_:)` | `CGDisplayInfoProvider` (via `infoProvider.isBuiltin`) | Identifies the internal display |
| Online display list (CoreGraphics query in `DisplayInfoProvider`) | `DisplayManager`, `performEmergencyCheckIfNeeded` | The provider filters WindowServer's synthetic placeholder ID; an empty list means a genuine unplug |
| `CGDisplayRegisterReconfigurationCallback(_:_:)` | `AppDelegate` | Fires per-display; includes `.beginConfigurationFlag` intermediate events |
| `CGError` | everywhere | Only `.success` counts; never assume success |

## Common patterns

```swift
var configRef: CGDisplayConfigRef?
guard CGBeginDisplayConfiguration(&configRef) == .success else { return false }
guard privateSymbol(configRef, id, enabled ? 1 : 0) == .success else {
    CGCancelDisplayConfiguration(configRef)
    return false
}
return CGCompleteDisplayConfiguration(configRef, .forSession) == .success
```

- Reconfiguration callback: ignore events where `flags.contains(.beginConfigurationFlag)`; hop to `@MainActor` before touching manager/view-model state.
- Debounce by re-snapshotting: always take one `onlineDisplayIDs()` snapshot and derive both the log and the decision from it (see `performEmergencyCheckIfNeeded`).

## Gotchas

- `CGDirectDisplayID` is `UInt32`-backed and **not stable across reboots/reconfigurations in general** — this repo persists it for the internal panel only, which is stable enough for the app's own crash-recovery use.
- Once disabled, the internal display disappears from `NSScreen.screens` — never try to re-derive its ID after disabling; use the cached/persisted value.
- The reconfiguration notification flurry can arrive mid-transaction; state flags must only be written after a successful complete.

## Do not use

- `CGConfigureDisplayMirrorOfDisplay` / brightness APIs as a substitute — they leave the panel active (the workaround this app exists to replace).
- Display reconfiguration calls on the main thread in a tight loop; keep transactions sequential.
