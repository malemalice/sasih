# SkyLight Private API Reference

> Repo: mac-app-blackout (single repo)
> Version: macOS 13+ (Apple Silicon), symbol names current as of macOS 16
> Source: no public documentation; derived from TRD §2 and the reference implementation `RonaldPark89/InternalDisplayOff` (read-only reference — do not copy code)
> Last updated: 2026-09-22

## Overview

The only way a third-party app can disable just the built-in display while the lid is open. Private, undocumented, and can change or vanish in any macOS release. It is loaded at runtime — never linked.

## Key APIs used in this repo

```swift
typealias ConfigureDisplayEnabledFn = @convention(c) (OpaquePointer?, CGDirectDisplayID, Int32) -> CGError

dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)  // DlsymSymbolLookup
dlsym(handle, "SLSConfigureDisplayEnabled")   // primary
dlsym(handle, "CGSConfigureDisplayEnabled")   // legacy fallback
// called with Int32 1 = enable, 0 = disable, inside a CG display transaction
```

Used by: `Sources/SasihCore/PrivateAPI/DisplayConfigSymbolResolver.swift`, `DisplayConfiguring.swift`.

## Common patterns

- Resolve **once per call** via `SymbolResolution.resolve(using:)`; try primary then legacy, first hit wins.
- Always wrap the call in `CGBeginDisplayConfiguration` → symbol → `CGCompleteDisplayConfiguration(.forSession)`; cancel with `CGCancelDisplayConfiguration` on any non-`.success` return.
- Diff current vs. target display state before issuing a change (`DisplayStateDiff`) — issuing a change for a display already in the target state fails the entire transaction.

## Gotchas

- **No entitlement path.** `SLSDisplayPowerControlClient.requestStateChange` + `kSLSDisplayControlRequestClamshellState` requires `com.apple.private.SkyLight.displaypowercontrol`, which AMFI will not grant non-Apple-signed binaries. Confirmed dead end (Alin Panaitiu / Lunar). Do not spend time here.
- **Per-display callbacks:** macOS fires one `CGDisplayReconfigurationCallback` event per disabled display, not one per transaction — and `.beginConfigurationFlag` intermediate events must be ignored.
- **RTLD_NOW** is used; a nil `dlopen` means SkyLight isn't loadable at all — treat identically to "symbol missing".
- **Never link the framework at build time** — there is no header and no stable ABI promise; `dlopen`/`dlsym` is the only safe route.
- The disable is a **WindowServer-session-only flag**: it does not survive reboot, and the system re-enables all displays on wake. That property is what makes the "reboot" manual recovery path always work.

## Do not use

- Any compile-time linking (`-framework SkyLight`, `@_silgen_name`) — no build-time dependency allowed.
- The clamshell-state XPC API (entitlement dead end).
- Any invented "public" wrapper names not in `SymbolResolution.candidateNames` without verifying by disassembly/`nm` first.
