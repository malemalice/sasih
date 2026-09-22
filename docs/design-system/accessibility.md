# Accessibility

## Implemented

| Requirement | Implementation |
|---|---|
| The menu-bar glyph conveys state to VoiceOver | `Image(...).accessibilityLabel("Sasih — internal display off" / "Sasih — internal display on")` in `SasihApp.swift` |
| Text contrast in light/dark mode | Semantic colours (`.secondary`, label colours) adapt automatically |
| Hit targets | Native `Toggle(.switch)` and full-width `MenuRow` buttons (≥ 22 pt) |
| State is not colour-only | Status caption is textual ("Blackout active" / "Standing by") in addition to the glyph and switch |

## Rules for new UI

1. Every icon-only or state-bearing image needs an `accessibilityLabel`.
2. Never rely on colour alone to convey state — pair it with text (this app already follows this: the amber dot idea from the plan was deliberately not needed).
3. Do not override system font sizes with fixed point sizes beyond what exists; if adding text, prefer semantic `Font` styles over `.system(size:)` where it doesn't break the dense menu layout.
4. The switch's `help(...)` tooltips describe the action in plain language — keep them when copy changes (they are also the screen-reader-adjacent affordance for the control's purpose).

## Not applicable

- Touch target minimums for touchscreens (macOS pointer UI).
- Reduced-motion support (no custom motion — see `motion.md`).
