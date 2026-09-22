# Entities

## 1. Persisted entities (`DisplayIDPersisting` — real impl `DisplayIDStore`)

| Entity (UserDefaults key) | Type | Default | Written when | Read when | Purpose |
|---|---|---|---|---|---|
| `BackupInternalDisplayID` | `Int` (`CGDirectDisplayID` = `UInt32`) | none (absent) | just before a successful disable, and on every disable | init; `enableInternalDisplay()` fallback; `restoreOnLaunchIfNeeded()` | The internal display's ID must be cached *before* disabling — after disable it disappears from `NSScreen.screens` and can't be re-identified |
| `IsInternalDisplayOff` | `Bool` | `false` (absent = false) | on every successful disable/enable; `handleWake()` `leaveOn` path only once the panel is verified online (or restored); emergency-check reconciliation when the online list proves the recorded state wrong | init; `handleWake()`; `restoreOnLaunchIfNeeded()` | Crash/force-quit recovery and sleep/wake state restoration |
| `AutoRevertInternalOffOnReconnect` | `Bool` | `true` (opt-out) | when the user flips the "Auto-Blackout" toggle | init; `performEmergencyCheckIfNeeded()` | User preference: re-apply "internal off" automatically when an external display reconnects after a fallback |

## 2. Backup file entity

| Path | Format | Purpose |
|---|---|---|
| `~/.sasih_internal_display_id` | plain text `UInt32` (whitespace-trimmed) | Belt-and-suspenders copy of `BackupInternalDisplayID`; used only when the UserDefaults value is missing/unreadable |

There is intentionally **no** backup file for `IsInternalDisplayOff` — the off-state is only recoverable while UserDefaults lives; a wiped UserDefaults means the app assumes "on", which is the safe direction (see `notes.md`).

## 3. Runtime entities (`DisplayManager`, in-memory only)

| Field | Type | Lifetime | Meaning |
|---|---|---|---|
| `isInternalDisplayOff` | `Bool` (`private(set)`) | process | Single source of truth for UI + safety nets |
| `lastError` | `String?` (`private(set)`) | process | Last user-facing error ("No external display detected.", "Failed to disable internal display.", …) — cleared on success |
| `cachedInternalDisplayID` | `CGDirectDisplayID?` | process | In-memory copy of the persisted ID (loaded in `init`) |
| `internalOnIsFallback` | `Bool` | process (never persisted) | Internal is on only because no external was present at decision time — gates auto-revert |

## 4. Runtime entities (view layer)

| Field | Type | Source | Meaning |
|---|---|---|---|
| `DisplayStateViewModel.isInternalDisplayOff` | `@Published Bool` | `manager` | Drives menu bar icon + toggle |
| `DisplayStateViewModel.lastError` | `@Published String?` | `manager` | Error caption row |
| `DisplayStateViewModel.hasExternalDisplay` | `@Published Bool` | `manager.externalDisplayCount > 0` | Drives disabled state of the toggle |
| `DisplayStateViewModel.autoRevertOnReconnectEnabled` | `@Published Bool` (didSet writes through) | `manager` | Auto-Blackout toggle |
