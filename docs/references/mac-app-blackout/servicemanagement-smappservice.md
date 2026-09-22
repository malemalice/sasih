# ServiceManagement `SMAppService` Reference

> Repo: mac-app-blackout
> Version: macOS 13+ (`SMAppService` modern API)
> Source: Apple ServiceManagement docs
> Last updated: 2026-09-22

## Overview

Registers the app itself as a login item. Replaces the deprecated `SMLoginItemSetEnabled`/helper-bundle approach.

## Key APIs used in this repo

```swift
SMAppService.mainApp.status == .enabled
try SMAppService.mainApp.register()
try SMAppService.mainApp.unregister()
```

Used in `Sources/SasihApp/LaunchAtLogin.swift`. The menu reads `isEnabled` when the view is created and writes through on toggle change.

## Common patterns

- Always guard on `status` before (un)registering — calling `register()` when already enabled or `unregister()` when not enabled throws.
- Failures here are non-fatal by design: the menu toggle may show a stale state, but display-safety behaviour must never depend on login-item registration.

## Gotchas

- `SMAppService.mainApp` requires the app to be a real `.app` bundle in a stable location; running the bare executable or a copy in a random folder makes registration unreliable. The DMG install flow (drag to `/Applications`) exists partly for this.
- On recent macOS, the user can also toggle the login item in System Settings → General → Login Items; `status` reflects that, so the menu toggle must be read at open time (hence `@State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled` is initialized per view creation).
- Errors are currently swallowed (empty `catch`) — if debugging registration, log the thrown error temporarily rather than changing the control flow.

## Do not use

- `SMLoginItemSetEnabled` (deprecated) or a helper-bundle login item.
- `LaunchServices` write hacks for login items.
