# Error Taxonomy

## Contract A — private SkyLight symbol

| Failure | Detection | Required handling | User-visible result |
|---|---|---|---|
| Neither symbol resolves (removed/renamed in a future macOS) | `SymbolResolution.resolve` returns `nil` | `setDisplay` returns `false`; **no** crash, **no** silent no-op | `DisplayManager.lastError = "Failed to disable internal display."` (or enable equivalent) → caption in menu |
| `CGBeginDisplayConfiguration` non-success | `result != .success` | Return `false`, nothing to cancel | same as above |
| Symbol call returns non-success (e.g. display already in target state) | `CGError != .success` | `CGCancelDisplayConfiguration`, return `false` | same as above |
| `CGCompleteDisplayConfiguration` non-success | `CGError != .success` | Return `false` (state flags not updated) | same as above |
| Guard refusal (no external / last active display) | `DisplayGuards` | Refuse before touching the API | "No external display detected." / "Refusing to disable the last active display." |
| Internal display ID unknown | `cachedInternalDisplayID == nil && idStore.load() == nil` | Refuse the enable | "Internal display ID unknown — cannot restore." |

**Invariant:** failure must always leave the *actual* system state untouched or restored — never set `isInternalDisplayOff` optimistically. `lastError` is cleared only on a fully successful transaction.

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
