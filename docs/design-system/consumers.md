# Consumers

Single-repo product — exactly one consumer, no distribution mechanism needed.

| Consumer | How it consumes |
|---|---|
| `SasihApp` (menu bar app) | Implements this design system directly in `Sources/SasihApp/MenuBarView.swift` and `SasihApp.swift`; ships the icon assets in `Sources/SasihApp/Resources/` |

There is no npm package, no shared component library, and no cross-repo consumption. If a second surface is ever added (e.g. a landing page), it should read this design system for icon and accent decisions but will re-implement, not import.

## Change protocol

- Changing a token in `tokens.md` requires the matching change in `MenuBarView.swift` (or vice versa) in the same commit.
- Replacing an icon asset requires updating `icons.md` and re-running the manual UI checks in `playbooks/hardware-verification.md` (menu bar readability on light/dark bars).
