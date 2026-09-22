# Constraints & Integrations — mac-app-blackout (Sasih)

> Migrated from the former repo-root `TRD.md` §2, §5, §6 plus integration points found in code.

## 1. The private API (core constraint)

### 1.1 The symbol

- Symbol: `SLSConfigureDisplayEnabled` (primary), fallback to older name `CGSConfigureDisplayEnabled`.
- Location: private framework `/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight`.
- Resolved at runtime via `dlopen` + `dlsym` (not linked at compile time — no header exists; this is expected for a private symbol). See `Sources/SasihCore/PrivateAPI/DisplayConfigSymbolResolver.swift`.
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

### 1.2 Why this API and not the "correct" one

macOS's real clamshell mode is driven by `powerd` calling `SLSDisplayPowerControlClient.requestStateChange(_:error:)` with `kSLSDisplayControlRequestClamshellState`. That call requires the `com.apple.private.SkyLight.displaypowercontrol` entitlement, which AMFI refuses to grant to any non-Apple-signed binary — confirmed via independent reverse-engineering research (Alin Panaitiu / Lunar author, public blog post). This path is a dead end for a third-party app, entitlement or no entitlement, SIP on or off.

`SLSConfigureDisplayEnabled` does not require that entitlement — it's a lower-level "remove this display from the system" call (closer to a software disconnect than a true power-state transition), reachable via plain `dlopen`/`dlsym`. Confirmed working via an independent open-source reference implementation (see §1.3).

### 1.3 Reference implementation

[RonaldPark89/InternalDisplayOff](https://github.com/RonaldPark89/InternalDisplayOff) — public GitHub repo, no LICENSE file (treat as read-only reference for the *technique and safety-net design*, do not copy code verbatim). Confirms:

- The exact symbol/signature above works on real hardware.
- macOS fires one `CGDisplayReconfigurationCallback` event per disabled display, not one per transaction — state tracking must account for this.
- Calling `SLSConfigureDisplayEnabled` on an already-disabled display fails the entire transaction — always diff current vs. target state before building the change list.

### 1.4 Platform constraint

Apple Silicon only, macOS 13 (Ventura) or later. Reasoning: this is the same generation/constraint that Lunar's BlackOut-via-disconnect feature targets (per public changelog), and is the version the reference implementation was built/tested against. Do not attempt to support Intel Macs or pre-Ventura — different display stack internals, unverified and out of scope.

## 2. Distribution constraint

- Direct download, signed with a Developer ID Application certificate; **never** Mac App Store (private API usage is an automatic App Review rejection; PRD rules it out permanently).
- Requires an active Apple Developer Program membership for the Developer ID cert.

## 3. Entitlements / sandboxing

- App runs **unsandboxed** (App Sandbox is incompatible with `dlopen`-ing a private system framework in practice, and irrelevant outside the App Store anyway).
- No special entitlements required beyond standard code-signing — this is the key advantage of `SLSConfigureDisplayEnabled` over the clamshell-state XPC approach.

## 4. Risk register

| Risk | Mitigation | Where in code |
|---|---|---|
| Private symbol renamed/removed in a future macOS release | Try both `SLSConfigureDisplayEnabled` and `CGSConfigureDisplayEnabled` at runtime; fail gracefully (visible error in menu, no silent black screen) if neither resolves | `DisplayConfigSymbolResolver.SymbolResolution.resolve`; `PrivateAPIDisplayConfigurer.setDisplay` returns `false`; surfaced as `DisplayManager.lastError` |
| Internal display ID lookup fails after disable (can no longer query `NSScreen` for it) | Cache the ID persistently *before* disabling, from multiple sources (UserDefaults + file) | `DisplayIDStore` (keys in `erd/notes.md`) |
| Calling the private symbol on an already-target-state display fails the whole transaction | Always resolve current state before building the change list | `DisplayStateDiff`, `DisplayManager.disableInternalDisplay()` guards |
| User left with no visible display | Safety nets; top-priority correctness requirement | `performEmergencyCheckIfNeeded`, backstop timer, `restoreOnLaunchIfNeeded`, `restoreBeforeQuit`, `handleWake` |
| App Store rejection if ever submitted by mistake | Non-issue — direct distribution only, a permanent decision | PRD; `deployment.md` |
| **Touch Bar goes blank (touch/digitizer still responds) after disable→enable on 13" M1/M2 MacBook Pro** | In-app nudge; see §5 below | `TouchBarRecovery.swift`, called from `DisplayStateViewModel.toggle()` |

## 5. Touch Bar constraint (13" M1/M2 MacBook Pro — the only Apple Silicon Touch Bar models)

Reproduced 2026-08-23. Ruled out: `killall ControlStrip` alone does not fix it; `killall ControlStrip` + `sudo killall TouchBarServer` together also does not fix it — the Touch Bar's DFR session is stuck at the WindowServer level, below what user/daemon restarts can reach.

Confirmed fixes:

1. full logout/login (restarts WindowServer — disruptive, closes all apps),
2. a display sleep→wake cycle (`pmset displaysleepnow`, then wake) — much lighter, apps stay open.

**Mitigated in-app** via `TouchBarRecovery.swift` (`SasihApp` target): after `DisplayStateViewModel.toggle()` transitions the internal display off→on, if `TouchBarServer` is running (Touch Bar hardware detected via `pgrep -x TouchBarServer`), it shells out to `pmset displaysleepnow` then `caffeinate -u -t 1` ~0.5s later to force an immediate wake — reproducing the manually-confirmed fix without requiring the user to notice or intervene. Verified working live 2026-08-23.

Root cause still unconfirmed (suspected: `SLSConfigureDisplayEnabled` doesn't send whatever reconfiguration signal a "real" display change sends to resignal DFR). This is a mitigation, not a root-cause fix — keep an eye on edge cases: the wake-from-sleep and crash-recovery paths deliberately do **not** call this nudge (it would race the app's own reconfiguration callbacks).

## 6. External integrations

| Integration | Direction | Contract | Code |
|---|---|---|---|
| GitHub Releases API | outbound HTTPS GET | `GET /repos/malemalice/sasih/releases/latest`; reads `tag_name`, `html_url`; unauthenticated | `Sources/SasihApp/UpdateChecker.swift` — see `api-contracts/` |
| `pmset`, `caffeinate`, `pgrep` | shell-out (`/usr/bin/...`) | Exit-status only; no output parsed | `Sources/SasihApp/TouchBarRecovery.swift` |
| `SMAppService.mainApp` | system service registration | `status`, `register()`, `unregister()`; failures non-fatal | `Sources/SasihApp/LaunchAtLogin.swift` |
| Unified log (`os.Logger`) | outbound diagnostics | Subsystem `com.adaptivid.sasih`; categories `DisplayManager`, `AppDelegate`; all interpolations `privacy: .public` | throughout |
| Update source (this repo's releases) | inbound | Versioning + asset contract: see `deployment.md` §3 |

## 7. No third-party dependencies

SwiftPM `dependencies` is empty. Every dependency is an Apple system framework or a CLI tool shipped with macOS. Any proposal to add a third-party package is a product/scope decision (this is a deliberately tiny, dependency-free utility) and requires explicit approval.
