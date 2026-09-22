# Tokens

> Extracted from `Sources/SasihApp/MenuBarView.swift` and `Sources/SasihApp/SasihApp.swift`.
> This app uses macOS semantic styles where possible; the literal values below are the
> current implementation, not a license to hard-code more of them.

## Typography

| Token | Value | Used for |
|---|---|---|
| Title | `.system(size: 13, weight: .semibold)` | "Sasih" header |
| Body / control | `.system(size: 13)` | Toggle row labels, menu rows (About / Check for Updates / Support / Quit) |
| Caption | `.system(size: 11)` | Status caption, hint & error captions |
| Icon-in-caption | `.system(size: 10)` | Warning triangle in the error row |

## Colour

| Token | Value | Used for |
|---|---|---|
| Primary text | default label colour | Titles, control labels |
| Secondary text | `.secondary` / `NSColor.secondaryLabelColor` | Status caption, hints, error text, About credits |
| Warning | `Color.orange` | Error row triangle |
| Hover highlight | `Color.primary.opacity(0.08)` | `MenuRow` hover fill (mimics native menu items) |
| Brand accents (app icon only) | near-black panel `#0A0A0C`, warm monitor glow `#F5A623`, neutral hardware grey `#8A8D93`-ish | App icon; **one** warm accent only |

Rules:

- One warm accent, reused if the status-tint idea (PRODUCT_PLAN §3) is ever implemented — never introduce a second accent.
- No hard-coded colours in view code except the ones already there; prefer semantic styles so light/dark mode and accessibility settings are automatic.

## Spacing

| Token | Value | Where |
|---|---|---|
| Panel width | 280 pt | `.frame(width: 280)` — the whole menu surface |
| Horizontal inset | 14 pt | rows and captions |
| Row vertical padding | 8 pt (control rows), 6 pt (`MenuRow`) | |
| Header padding | top 12 / bottom 10 | |
| Stack gaps | 2 pt (stacked caption), 5 pt (icon+text), 10 pt (header icon+title) | |

## Shapes & chrome

- Native switch style for all toggles (`.toggleStyle(.switch)`), labels hidden, aligned right.
- Dividers between sections; extra `Divider().padding(.vertical, 4)` before the action list.
- No custom backgrounds, gradients, or rounded containers on the menu surface.
