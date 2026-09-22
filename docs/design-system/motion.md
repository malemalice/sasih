# Motion

Deliberately minimal.

| Interaction | Motion |
|---|---|
| Toggle switch | Native SwiftUI switch animation — do not override |
| Menu open/close | System-provided `MenuBarExtra` window behaviour |
| Hover on `MenuRow` | Instant fill change (no explicit animation) — matches native menu behaviour |
| Menu-bar glyph swap (on/off) | Instant asset swap based on state; no cross-fade |
| Update check in flight | Label swap "Check for Updates…" → "Checking…"; no spinner |

Rules:

- No custom animation curves, durations, or transitions in this app. If a proposed change needs motion to be understood, redesign the state communication instead (use text/icon state).
- Never animate anything on the display-reconfiguration paths — those run while the screen set is in flux.
