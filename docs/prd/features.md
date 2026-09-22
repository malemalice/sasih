# Features

## User stories (MVP)

1. As a user, I can click a menu-bar icon and toggle "Turn off built-in display" on or off.
2. As a user, if I unplug my external display while the internal one is off, the internal display automatically turns back on — I am never left with zero active displays.
3. As a user, if the app crashes or is force-quit while the internal display is off, it is restored automatically (on next launch, or via a background safety check).
4. As a user, if I quit the app normally, the internal display is restored before it exits.
5. As a user, I can enable "Launch at Login" so this is always available without manual setup.
6. As a user, my keyboard, trackpad, Touch Bar, and speakers continue to work exactly as before — no behavior change is expected or acceptable here.
7. As a user, after my Mac sleeps and wakes, my last chosen state (off/on) is restored automatically.

## Implemented feature surface (as of v0.1.4)

| Feature | UI label | Code |
|---|---|---|
| Toggle internal display off/on | "Blackout" | `Sources/SasihCore/DisplayManager.swift`, `Sources/SasihApp/MenuBarView.swift` |
| Never strand the user (auto-restore) | (safety nets, no UI) | `DisplayManager.performEmergencyCheckIfNeeded()`, `restoreOnLaunchIfNeeded()`, `restoreBeforeQuit()`, `handleWake()` |
| Auto-Blackout on external reconnect | "Auto-Blackout" | `DisplayManager.autoRevertOnReconnectEnabled` (persisted, default on) |
| Launch at Login | "Launch at Login" | `Sources/SasihApp/LaunchAtLogin.swift` (`SMAppService.mainApp`) |
| Update check | "Check for Updates…" | `Sources/SasihApp/UpdateChecker.swift` (GitHub Releases API) |
| Touch Bar blank-panel recovery | (invisible) | `Sources/SasihApp/TouchBarRecovery.swift` |
| Support link | "Support Sasih" | `MenuBarView.openSupportPage()` → ko-fi.com/malemalice |

## Product risks

- The mechanism relies on an undocumented private macOS API. Apple could change or remove it in a future macOS release, breaking the app until updated. Mitigated by: no other viable approach exists for this feature (confirmed via reference implementations from other shipping apps); accept and monitor across macOS updates.
- Because it uses a private API, this app can never ship on the Mac App Store — acceptable, already decided (direct distribution).
- **Touch Bar (on the 13" M1/M2 MacBook Pro, the only Apple Silicon Touch Bar models) can go blank — though still touch-responsive — after a disable→enable cycle.** Previously required a full logout/login to fix; now mitigated automatically in-app via a display sleep/wake nudge triggered right after re-enabling the internal display (see `trd/mac-app-blackout/constraints-integrations.md`). User story 6 is met in practice, though the underlying WindowServer-level cause is still unconfirmed — treat this as a working mitigation, not a guaranteed-permanent fix.
