# Relationships & State Machine

## Internal-display state machine

```
                disableInternalDisplay()
        (requires externalCount > 0
         and activeDisplayCount > 1)
   ┌──────────────────────────────────────┐
   │                                      ▼
[ON]                                   [OFF]
   ▲                                      │
   │      enableInternalDisplay()         │
   └──────────────────────────────────────┘
        (always safe; used by all restore paths)

Fallback sub-state (only reachable from OFF):
[OFF] + external unplugged detected (callback or 10s backstop)
   → enableInternalDisplay(), internalOnIsFallback = true
   → state is [ON·fallback]

[ON·fallback] + external reconnected + Auto-Blackout enabled
   → disableInternalDisplay(), internalOnIsFallback = false
[ON·fallback] + any manual toggle
   → internalOnIsFallback = false (user chose deliberately)
```

## Reconciliation branches (added 2026-09-22, working tree)

The panel being **absent from the online list is ground truth that it is off** — the recorded
state must converge to it, not the other way around:

- `disableInternalDisplay()` when the panel is already offline: record `isInternalDisplayOff = true` + persist, return `true`, **no hardware call**. (Also avoids a doomed transaction and a permanent last-active-display refusal.)
- `performEmergencyCheckIfNeeded()` when state says ON but the panel is offline, and (`externalCount == 0` or we're inside the fallback window): record `isInternalDisplayOff = true` + persist, clear `internalOnIsFallback`. A transient external-present blip outside the fallback window is ignored (the online list can omit the panel mid-reconfiguration).
- `handleWake()` `.leaveOn`: set `internalOnIsFallback = true`; if the panel is online, record ON; if macOS did **not** restore it, call `enableInternalDisplay()` explicitly — and if that fails, keep `IsInternalDisplayOff == true` so the emergency check and launch restore keep retrying instead of claiming the panel is on.

Single-panel helper: `isInternalDisplayOnline(in:)` (`onlineIDs.contains(where: infoProvider.isBuiltin)`).

## UI mutation contract

`DisplayStateViewModel.setBlackoutActive(_:)` is the only way UI writes the toggle: it no-ops when the requested value equals current state, otherwise calls `toggle()`. This makes the switch **intent-based** (a stale click after an automatic change can't invert the outcome) and idempotent.

## Invariants

1. `isInternalDisplayOff == true` ⇒ `IsInternalDisplayOff == true` in UserDefaults (same transaction, `saveOffState` on every transition). The reverse is also maintained: every enable writes `false`.
2. `isInternalDisplayOff == true` ⇒ an external display was present at the moment of disabling. It may be absent later (that triggers the emergency restore).
3. The app never disables the last active display, and never disables without an external — two independent guards (`DisplayGuards.canDisableInternal` + `DisplayGuards.isLastActiveDisplay`).
4. `internalOnIsFallback` is never persisted: a fresh process starts with no fallback to reconcile.

## Wake behaviour (`SleepWakeDecision`, pure)

| `wasOffBeforeSleep` | external present on wake | Action |
|---|---|---|
| `true` | `true` | `.reapplyOff` → `disableInternalDisplay()` |
| `true` | `false` | `.leaveOn` → `internalOnIsFallback = true`; if the panel is online record ON, else call `enableInternalDisplay()` explicitly (keep OFF recorded if that fails, so retries continue) |
| `false` | any | `.doNothing` |

## Auto-revert preference relationship

`AutoRevertInternalOffOnReconnect` (persisted) is consulted **only** in the `[ON·fallback]` branch of `performEmergencyCheckIfNeeded()`. It never affects a user-initiated toggle, and never affects the emergency restore direction (restore is unconditional — no preference can keep a black-only setup).
