# Storage Notes & Failure Modes

## Storage locations

| Store | Location | Scope |
|---|---|---|
| Primary | `UserDefaults.standard` | Per-user, conventional |
| Backup | `~/.sasih_internal_display_id` (home dir, atomically written) | Per-user; survives UserDefaults wipe |

`DisplayIDStore.init(defaults:fileURL:)` accepts both so tests can inject an isolated `UserDefaults` suite and a temp file path.

## Privacy

- Nothing leaves the machine except: the GitHub Releases API GET (no user data, no identifiers) and the user-initiated ko-fi link. No analytics, no accounts, no telemetry.
- The backup file contains a display ID — a hardware/config identifier stored locally, readable only by the user (`~` permissions per umask). Treat it as machine-local config, not a secret.

## Failure modes and chosen safe directions

| Failure | Effect | Why it's safe |
|---|---|---|
| Backup file unreadable/corrupt | Falls back to UserDefaults value | Read order: UserDefaults → file |
| UserDefaults wiped | `load()` falls back to file; `loadOffState()` → `false` | Assuming "on" never strands the user; the real display state is anyway re-derived from `CGDisplayInfoProvider` before any disable |
| Both stores missing after a crash while off | On next launch `restoreOnLaunchIfNeeded()` does nothing (thinks it was on) | The system itself re-enables all displays on reboot; a disabled-by-our-transaction state does not survive reboot (WindowServer-session-only flag) |
| File path collision (another app) | Not expected — `.sasih_` prefix | — |

## Test coverage pointers

- Round-trip + one-store-missing behavior: `Tests/SasihCoreTests/DisplayIDStoreTests.swift`
- Fallback-flag / auto-revert branch: `Tests/SasihCoreTests/DisplayManagerTests.swift`
- Persisted-state recovery on launch: `DisplayManagerTests` (`restoreOnLaunchIfNeeded` cases)

## Non-goals

- No migration/versioning of stored keys (single-user utility; keys are stable and additive).
- No encryption — nothing sensitive.
