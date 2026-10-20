# Endpoints / Call Shapes

## B.1 `GET /repos/malemalice/sasih/releases/latest`

| Field | Value |
|---|---|
| URL | `https://api.github.com/repos/malemalice/sasih/releases/latest` |
| Headers | `Accept: application/vnd.github+json` |
| Auth | none |
| Success | HTTP 200 + JSON body |

Response fields consumed (decoded into `GitHubRelease`; other fields ignored):

| JSON key | Swift | Use |
|---|---|---|
| `tag_name` | `tagName` | Leading `v` stripped → compared with `VersionComparison.isNewer(latest, than: currentVersion)` |
| `html_url` | `htmlURL` | Opened by the browser when the user chooses "Download" |

Not consumed: assets, body/changelog, `published_at`, `prerelease`, etc.

Non-200 (including 404 when no release exists, 403 on rate limit) → `.failed("Couldn't reach GitHub to check for updates.")`.

## A.1 Display enable/disable transaction (private symbol)

```
CGBeginDisplayConfiguration(&configRef)                     // public
  configureDisplayEnabled(configRef, displayID, 0|1)        // private: 0 = disable, 1 = enable
CGCompleteDisplayConfiguration(configRef, .forSession)      // public
  ↳ on any non-success CGError: CGCancelDisplayConfiguration(configRef)
```

| Property | Value |
|---|---|
| `displayID` | The cached internal `CGDirectDisplayID` (must be persisted *before* a disable) |
| Enabled value | `Int32` — `1` enable, `0` disable |
| Return | `CGError`; any non-`.success` aborts the transaction and `setDisplay` returns `false` |
| Precondition | Never issue a change for a display already in the target state (fails the whole transaction) — see `DisplayStateDiff`. `disableInternalDisplay()` checks the panel is absent from the online list; `enableInternalDisplay()` deliberately always attempts the call (the online list can hold a ghost builtin entry) and, if the call is rejected, treats the builtin being online as success |

## A.1b Stop / start mirroring (public CoreGraphics, added 2026-10-20)

```
CGBeginDisplayConfiguration(&configRef)
  CGConfigureDisplayMirrorOfDisplay(configRef, id, master)   // per external id
                                    // stop:  master = kCGNullDirectDisplay
                                    // start: master = builtin display ID
CGCompleteDisplayConfiguration(configRef, .forSession)
  ↳ on a per-id non-success: CGCancelDisplayConfiguration(configRef)
```

| Property | Value |
|---|---|
| Caller (stop) | `DisplayManager.disableInternalDisplay()`, only when the usable-external guard refuses and `mirroredExternalDisplayIDs()` is non-empty |
| Caller (start) | `DisplayManager.remirrorIfReady()` — after a user `toggle()` that turned Blackout off or cancelled a pending blackout, only for IDs Sasih itself un-mirrored, only once the builtin is in the active list and those externals are still active |
| Effect | Stop takes the externals out of their mirror set; start mirrors them back onto the builtin. Both screens stay on. `.forSession` → the user's mirror preference also returns at next login (backstop) |
| Return | `Bool` (`stopMirroring(_:)` / `startMirroring(_:of:)`, shared `configureMirroring(_:of:)`); `false` on empty ids or any non-`.success` |
| Not a disable | Never darkens a display; the blackout itself is still A.1, applied later by the guarded disable once the external is drawable |

## A.2 Display queries (public CoreGraphics)

| Call | Use |
|---|---|
| `CGGetOnlineDisplayList` / provider equivalent | Current online display IDs (`DisplayInfoProviding.onlineDisplayIDs()`) |
| `CGDisplayIsBuiltin` | Identify the internal display (`isBuiltin(_:)`) |
| `CGDisplayIsInMirrorSet` (+ online minus active, non-builtin) | Hardware-mirrored externals (`mirroredExternalDisplayIDs()`, added 2026-10-20) — online but not drawable |
| `CGDisplayRegisterReconfigurationCallback` | Observe external plug/unplug; ignore `.beginConfigurationFlag` events |

Note: the provider filters a WindowServer synthetic placeholder ID out of the online list — an empty list is the intended signature of a genuine unplug.
