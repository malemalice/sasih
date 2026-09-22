# Icons

> Migrated from `PRODUCT_PLAN.md` §2, updated to match the shipped implementation
> (the SF Symbol idea was dropped — the menu-bar glyphs are custom PNG assets).

## Menu-bar (status item) glyph

| Property | Value |
|---|---|
| Files | `Sources/SasihApp/Resources/MenuBarIcon-on.png`, `MenuBarIcon-off.png` |
| Rendering size | 18×18 pt (`image.size = NSSize(width: 18, height: 18)`) |
| Template image | **Yes** — `image.isTemplate = true`. Required, not stylistic: macOS then auto-adapts to light/dark menu bars and selection states |
| Concept | Gibbous-moon silhouette matching the app icon — **filled** when the display is on, **outlined/hollow** when off |
| Why full/rounded rather than a thin crescent | Avoids reading as the system Do Not Disturb status icon |

State mapping (also mirrored in the menu header caption):

- `MenuBarIcon-on` → full moon → "Standing by" (internal display on)
- `MenuBarIcon-off` → dark/hollow moon → "Blackout active" (internal display off)

When replacing: keep it a single monochrome path, no colour, no gradients, regular (not bold) stroke weight — must sit quietly next to system menu-bar icons at 18×18.

## App icon

| Property | Value |
|---|---|
| File | `Sources/SasihApp/Resources/AppIcon.icns` (bundled as `CFBundleIconFile = AppIcon`) |
| Composition | MacBook at a ¾ angle with the screen dark/off beside a lit external monitor — explains the entire product in one glance |
| Palette | near-black laptop screen `#0A0A0C`; one warm accent for the monitor glow (`#F5A623` or similar — pick one, never two); neutral cool grey hardware body (`#8A8D93`-ish, macOS-aluminium-adjacent) |
| Constraint | Must survive at 16×16 (Finder list view). If the two-device composition fails there, fall back to a single dark-screened laptop silhouette with a small light accent — no external monitor |
| Tooling | SF Symbols + Icon Composer / Keynote export is enough for v1; no designer needed. Revisit polish only if the app gets traction |

## Rules

1. The menu-bar glyph is a **template image**; the app icon is full colour. Never conflate the two jobs.
2. One warm accent colour total, shared between the app icon and any future status tint.
3. No icon-only controls inside the menu; icons accompany text, never replace it.
