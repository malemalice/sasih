# Components

## Menu surface (`MenuBarView`, `MenuBarExtra` with `.menuBarExtraStyle(.window)`)

Order and content are deliberate — do not add a preferences window, tabs, or onboarding for v1; the entire feature surface is one toggle and two preferences.

| Section | Component | Content / behaviour |
|---|---|---|
| Header | icon 30×30 (`NSApplication.applicationIconImage`) + "Sasih" + status caption | Caption mirrors state in words: "Blackout active" / "Starting blackout…" (blackout requested, waiting for a mirrored external to finish un-mirroring — usually a few seconds, ≤ 15 s) / "Standing by" |
| Divider | — | |
| Display | row: "Blackout" + switch | Switch is ON when blackout is active **or pending** (`isBlackoutShownActive = isInternalDisplayOff || isBlackoutPending`, so it doesn't bounce off-then-on while mirroring is stopped); flipping it off while pending cancels the pending blackout. Writes through `DisplayStateViewModel.setBlackoutActive(_:)`, which no-ops if the state already matches (auto-revert can flip state under a stale click). Disabled when `!hasExternalDisplay && !isBlackoutShownActive` (only the off-direction needs an external). `hasExternalDisplay` counts a usable external **or** a hardware-mirrored one (blackout stops mirroring first), so a mirrored-only setup no longer disables the switch. Tooltip differs per state. |
| Hint / error | caption row | If toggle disabled: "Connect an external display to turn this off." Else if `lastError`: warning triangle + error text (e.g. "Couldn't stop screen mirroring. Turn off Mirror in System Settings → Displays." when un-mirroring fails or times out). Otherwise hidden. |
| Divider | | |
| Auto-Blackout | row: "Auto-Blackout" + switch + caption | "Re-blackout automatically when your external display reconnects." Preference persisted. |
| Divider | | |
| Launch at Login | row: "Launch at Login" + switch | Writes through to `SMAppService` on change |
| Divider (extra 4 pt padding) | | |
| Actions | `MenuRow` × 4 | About Sasih · Check for Updates… (disabled + "Checking…" while in flight) · Support Sasih (ko-fi) · Quit Sasih |

## `MenuRow<Content>` (private reusable component)

Full-width button row that highlights on hover like native macOS menu items:

- Row: content + `Spacer()`, 14 pt horizontal / 6 pt vertical padding.
- Hover fill `Color.primary.opacity(0.08)` only when enabled.
- `.buttonStyle(.plain)`, `.contentShape(Rectangle())`, `.onHover`.
- Has an `isEnabled` parameter; disabled rows don't highlight.

Reuse `MenuRow` for any new menu action — do not build a parallel row style.

## Invariants

1. Every control is a labelled row with its control on the right — no icon-only controls, no hidden affordances. The whole point of the app is that the action is never ambiguous.
2. Status is legible without reading the switch (caption text, and menu-bar glyph swap).
3. Errors are visible but secondary (caption size 11, secondary colour) — never alerts for routine failures; `NSAlert` is reserved for the user-initiated update check result and About.
