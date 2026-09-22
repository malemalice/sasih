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
| Precondition | Never issue a change for a display already in the target state (fails the whole transaction) — see `DisplayStateDiff` |

## A.2 Display queries (public CoreGraphics)

| Call | Use |
|---|---|
| `CGGetOnlineDisplayList` / provider equivalent | Current online display IDs (`DisplayInfoProviding.onlineDisplayIDs()`) |
| `CGDisplayIsBuiltin` | Identify the internal display (`isBuiltin(_:)`) |
| `CGDisplayRegisterReconfigurationCallback` | Observe external plug/unplug; ignore `.beginConfigurationFlag` events |

Note: the provider filters a WindowServer synthetic placeholder ID out of the online list — an empty list is the intended signature of a genuine unplug.
