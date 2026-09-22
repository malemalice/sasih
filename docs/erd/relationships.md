# Relationships & State Machine

## Internal-display state machine

```
                disableInternalDisplay()
        (requires usableExternalCount > 0
         and activeDisplayCount > 1)
   ┌──────────────────────────────────────┐
   │                                      ▼
[ON]                                   [OFF]
   ▲                                      │
   │      enableInternalDisplay()         │
   └──────────────────────────────────────┘
        (always safe; used by all restore paths)

Fallback sub-state (only reachable from OFF):
[OFF] + usable external gone (no drawable external; callback or 10s backstop)
   → enableInternalDisplay(), internalOnIsFallback = true
   → state is [ON·fallback]

[ON·fallback] + usable external reappears + Auto-Blackout enabled
   → disableInternalDisplay(), internalOnIsFallback = false
[ON·fallback] + any manual toggle
   → internalOnIsFallback = false (user chose deliberately)
```

**"Usable external"** (used by every guard/restore/auto-revert decision) = online **and**
drawable (`CGDisplayIsActive` — connected, awake, available for drawing). The online list is a
superset that can retain stale/ghost or non-drawable hardware-mirror entries; treating those as
a working screen is what stranded users (field incident 2026-09-21). While the screens are in
display sleep nothing is drawable — so emergency checks are deferred (`screensAreAsleep`) rather
than read as "external gone".

## Reconciliation branches (added 2026-09-22, working tree)

The panel being **absent from the online list is ground truth that it is off** — the recorded
state must converge to it, not the other way around:

- `disableInternalDisplay()` when the panel is already offline: record `isInternalDisplayOff = true` + persist, return `true`, **no hardware call**. (Also avoids a doomed transaction and a permanent last-active-display refusal.)
- `performEmergencyCheckIfNeeded(screensAreAsleep:)` when state says ON but the panel is offline, and (`usableExternalCount == 0` or we're inside the fallback window): record `isInternalDisplayOff = true` + persist, clear `internalOnIsFallback`. A *drawable* external blip outside the fallback window is ignored (the online list can transiently omit the panel mid-reconfiguration) — but a merely listed, non-drawable external no longer holds the recorded state on.
- `handleWake()` `.leaveOn`: set `internalOnIsFallback = true`; if the panel is online, record ON; if macOS did **not** restore it, call `enableInternalDisplay()` explicitly — and if that fails, keep `IsInternalDisplayOff == true` so the emergency check and launch restore keep retrying instead of claiming the panel is on.
- While `screensAreAsleep` is true (display sleep), `performEmergencyCheckIfNeeded` changes nothing; the wake/reconfiguration events re-run it once displays are drawable again.

Single-panel helper: `isInternalDisplayOnline(in:)` (`onlineIDs.contains(where: infoProvider.isBuiltin)`).

## UI mutation contract

`DisplayStateViewModel.setBlackoutActive(_:)` is the only way UI writes the toggle: it no-ops when the requested value equals current state, otherwise calls `toggle()`. This makes the switch **intent-based** (a stale click after an automatic change can't invert the outcome) and idempotent.

## Invariants

1. `isInternalDisplayOff == true` ⇒ `IsInternalDisplayOff == true` in UserDefaults (same transaction, `saveOffState` on every transition). The reverse is also maintained: every enable writes `false`.
2. `isInternalDisplayOff == true` ⇒ a usable (drawable) external display was present at the moment of disabling. It may be absent later (that triggers the emergency restore).
3. The app never disables the last active display, and never disables without a usable external — two independent guards (`DisplayGuards.canDisableInternal` on the usable external count + `DisplayGuards.isLastActiveDisplay` on the active display count).
4. `internalOnIsFallback` is never persisted: a fresh process starts with no fallback to reconcile.
5. While the screens are asleep, recorded state is not changed by the emergency check: display sleep makes all displays non-drawable and must not be interpreted as an unplug.

## Wake behaviour (`SleepWakeDecision`, pure)

"External present on wake" means a **usable (drawable) external** — a merely listed entry falls
back to `.leaveOn`, and Auto-Blackout re-applies once the external is actually drawable.

| `wasOffBeforeSleep` | usable external present on wake | Action |
|---|---|---|
| `true` | `true` | `.reapplyOff` → `disableInternalDisplay()` |
| `true` | `false` | `.leaveOn` → `internalOnIsFallback = true`; if the panel is online record ON, else call `enableInternalDisplay()` explicitly (keep OFF recorded if that fails, so retries continue) |
| `false` | any | `.doNothing` |

## Auto-revert preference relationship

`AutoRevertInternalOffOnReconnect` (persisted) is consulted **only** in the `[ON·fallback]` branch of `performEmergencyCheckIfNeeded()`. It never affects a user-initiated toggle, and never affects the emergency restore direction (restore is unconditional — no preference can keep a black-only setup).
