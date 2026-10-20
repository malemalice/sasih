# Error Taxonomy

## Contract A — private SkyLight symbol

| Failure | Detection | Required handling | User-visible result |
|---|---|---|---|
| Neither symbol resolves (removed/renamed in a future macOS) | `SymbolResolution.resolve` returns `nil` | `setDisplay` returns `false`; **no** crash, **no** silent no-op | `DisplayManager.lastError = "Failed to disable internal display."` (or enable equivalent) → caption in menu |
| `CGBeginDisplayConfiguration` non-success | `result != .success` | Return `false`, nothing to cancel | same as above |
| Symbol call returns non-success (e.g. display already in target state) | `CGError != .success` | `CGCancelDisplayConfiguration`; for **enable**, re-read `onlineDisplayIDs()` once first — if the builtin is now online the end state is already the target, so record on and return `true`; otherwise return `false` | same as above (only when the panel really stayed off) |
| `CGCompleteDisplayConfiguration` non-success | `CGError != .success` | Return `false` (state flags not updated); the enable path still verifies the online list once and records success if the panel converged | same as above (only when the panel really stayed off) |
| Guard refusal (no external / last active display) | `DisplayGuards` | Refuse before touching the API | "No external display detected." / "Refusing to disable the last active display." |
| Guard refusal, but an external is hardware-mirroring | `canDisableInternal` refuses and `mirroredExternalDisplayIDs()` is non-empty | Call `stopMirroring(_:)` instead of refusing; on success set in-memory pending (15 s deadline), clear `lastError`, return `false` (no SkyLight call); the emergency check applies blackout via the guarded disable once the external is drawable | none — caption "Starting blackout…", switch shown on |
| `stopMirroring` fails (`CGBeginDisplayConfiguration`, any `CGConfigureDisplayMirrorOfDisplay`, or `CGCompleteDisplayConfiguration` non-success) | returns `false` | `CGCancelDisplayConfiguration` on a per-id failure; nothing pending, panel untouched | "Couldn't stop screen mirroring. Turn off Mirror in System Settings → Displays." |
| Pending un-mirror times out (external never became drawable within 15 s) | `performEmergencyCheckIfNeeded`, monotonic deadline passed | Clear pending and the re-mirror memory; no SkyLight call; panel stays on | same "Couldn't stop screen mirroring…" text |
| Re-mirror (`startMirroring`) fails or the builtin / externals aren't active yet | returns `false`, or builtin not in `activeDisplayIDs()` / remembered externals not active | Retry on each emergency check until `remirrorTimeout` (15 s), then clear the memory | none — screens just stay extended (nothing goes dark) |
| Internal display ID unknown | `cachedInternalDisplayID == nil && idStore.load() == nil`, and the builtin is not online | Refuse the enable | "Internal display ID unknown — cannot restore." |
| Enable called while the panel is already online | Builtin present in `CGGetOnlineDisplayList`; SkyLight rejects the no-op transaction | Post-failure re-read sees the builtin online → record on + clear `lastError` (no shortcut before the call: a ghost online entry must not skip a real restore) | none |

### Stop-mirroring flow (added 2026-10-20)

```
toggle on → disableInternalDisplay()
  usable external? ── yes → normal SkyLight disable
        │ no
  mirrored external? ── no → "No external display detected."
        │ yes
  stopMirroring(ids) ── fail → "Couldn't stop screen mirroring…"
        │ ok
  pending (≤15 s, both screens on, "Starting blackout…")
  emergency check (after sleep deferral):
    usable external now → clear pending → disableInternalDisplay() (all guards re-run)
    deadline passed     → clear pending → "Couldn't stop screen mirroring…"
    builtin online      → keep waiting
    builtin offline     → fall through to normal restore logic
  toggle() while pending → cancel (no SkyLight call) → re-mirror (below)

toggle off (enable ok) / cancel → scheduleRemirror() (only if Sasih un-mirrored; ≤15 s)
  remirrorIfReady() now, then on each emergency check (after sleep deferral + pending block):
    internal off / pending again → forget, no re-mirror
    builtin active && remembered externals active → startMirroring(ids, of: builtin)
        ok → done        fail → retry until deadline
    deadline passed → forget silently (screens stay extended)
  unplug restore (no drawable external) / wake .leaveOn → forget, no re-mirror
```

**Invariant:** failure must always leave the *actual* system state untouched or restored — never set `isInternalDisplayOff` optimistically. `lastError` is cleared only when the desired end state is verified: a successful transaction **or** observed reality already at the target (panel online for enable, absent for disable). One deliberate exception: a successful `stopMirroring` clears `lastError` while the blackout is pending (a stale "No external display detected." must not sit under "Starting blackout…"); `isInternalDisplayOff` is still not set until the guarded disable actually succeeds.

## Contract B — GitHub Releases API

`UpdateCheckResult` (enum in `UpdateChecker.swift`):

| Case | Trigger | UI |
|---|---|---|
| `.upToDate(current)` | 200, parsed, `!isNewer(latest, current)` | "You're Up to Date" alert |
| `.updateAvailable(current, latest, url)` | 200, parsed, newer semver | "Update Available" alert with Download / Later; Download opens `html_url` |
| `.failed(message)` | non-HTTP response; HTTP != 200 (incl. 404/403 rate limit); JSON decode failure; invalid `html_url` | "Couldn't Check for Updates" alert |

Rules:

- Update-check failures are **never** fatal, never retried automatically, and must not surface anywhere else in the UI.
- `VersionComparison` parses numerically (not lexicographically) and treats missing components as zero — see `Tests/SasihCoreTests/VersionComparisonTests.swift`.
