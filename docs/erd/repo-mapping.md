# Repo Mapping — where each entity lives

Single-repo product; all paths below are relative to the repo root (`mac-app-blackout/`).

| Entity | Definition | Real implementation | Tests |
|---|---|---|---|
| `DisplayIDPersisting` (protocol) | `Sources/SasihCore/DisplayIDStore.swift` | `DisplayIDStore` (same file) | `Tests/SasihCoreTests/DisplayIDStoreTests.swift` |
| `BackupInternalDisplayID` key | `DisplayIDStore.idKey` | `save(_:)` / `load()` | `DisplayIDStoreTests` |
| `~/.sasih_internal_display_id` file | `DisplayIDStore.fileURL` (injectable) | `save(_:)` / `load()` | `DisplayIDStoreTests` (temp path) |
| `IsInternalDisplayOff` key | `DisplayIDStore.offStateKey` | `saveOffState(_:)` / `loadOffState()` | `DisplayIDStoreTests` |
| `AutoRevertInternalOffOnReconnect` key | `DisplayIDStore.autoRevertKey` | `saveAutoRevertOnReconnect(_:)` / `loadAutoRevertOnReconnect()` | `DisplayIDStoreTests` |
| `isInternalDisplayOff` (runtime) | `Sources/SasihCore/DisplayManager.swift` | `DisplayManager` | `Tests/SasihCoreTests/DisplayManagerTests.swift` |
| `internalOnIsFallback` (runtime) | same | `DisplayManager.performEmergencyCheckIfNeeded()` / `handleWake()` | `DisplayManagerTests` |
| `isInternalDisplayOff` (UI mirror) | `Sources/SasihApp/DisplayStateViewModel.swift` | `DisplayStateViewModel` | `Tests/SasihAppTests/DisplayStateViewModelTests.swift` |
| `hasExternalDisplay` (UI mirror) | same | `DisplayStateViewModel.refresh()` | `DisplayStateViewModelTests` |

## Rules for future changes

1. Adding/removing a persisted key means touching `DisplayIDPersisting` (protocol), `DisplayIDStore` (impl), **and** `DisplayIDStoreTests` in the same change — the protocol is the contract.
2. Never persist `internalOnIsFallback` — its in-memory-only nature is a design decision (see `relationships.md` invariant 4).
3. Any change to the state transitions must update `relationships.md` in the same change.
