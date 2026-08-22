# Sasih — Product Plan (Indie Solo Release)

Scope: how to take the current MVP (menu-bar toggle for the internal display, per PRD.md/TRD.md) to a shipped, direct-distributed indie app. Covers naming, icon, UI design, and go-to-market — sized for a solo dev, not a team.

## 1. Name

**Sasih** — old Sundanese/Kawi word for "moon." Fits the user's existing GitHub naming convention (Sundanese nature words, alongside their mountains/rivers-named repos) and the app's core visual metaphor (`moon.fill` in the menu bar — the internal display "waning" off, then "waxing" back on). Renamed throughout the codebase: `Sasih` package, `SasihApp`/`SasihCore`/`SasihSpike` targets, bundle ID `com.adaptivid.sasih`.

Other Sundanese options considered and set aside:
- **Gerhana** (eclipse) — arguably the tightest metaphor (temporary, self-restoring darkness) but less literally "moon" than what was asked for.
- **Poék** ("dark") — most literal match to the old "Blackout" name, less distinctive.
- **Halimun** (mist/fog) — evokes obscuring rather than fully off, weaker fit.

## 2. Icon

Two distinct icon jobs — don't conflate them:

### Menu-bar (status item) icon
- Must be a **template image** (monochrome, macOS auto-adapts it to light/dark menu bars and to selection/active states) — this is an AppKit/NSStatusItem requirement, not a style choice.
- Concept: a simple laptop glyph (à la SF Symbols `laptopcomputer`) with the **screen area rendered as a solid dark rectangle** instead of the usual open/gradient screen — reads instantly as "the panel is off" at 18×18pt.
- Two states, swapped on toggle:
  - **Off (internal display disabled):** laptop glyph, screen filled solid (the "blackout" state) — this is the more visually distinct one since it's the state users need to confirm at a glance.
  - **On (normal):** laptop glyph, screen outline only / empty — matches the default SF Symbols look, low-key.
- Keep it a single path, no color, no gradients — SF Symbols-style stroke weight (regular, not bold) so it sits quietly next to system menu-bar icons.

### App icon (Finder, About panel, DMG background)
- Full color, single scene, no gradients-for-gradients'-sake: a **MacBook viewed at a ¾ angle, external monitor beside it**, the MacBook's screen dark/off and the external monitor lit — this is the one visual that explains the entire product in one glance (the actual use case: laptop screen off, external display on).
- Palette: near-black laptop screen (`#0A0A0C`), a single warm accent for the external monitor's glow (`#F5A623` or similar — pick one accent and don't add a second), neutral cool grey for the hardware body (`#8A8D93`-ish, macOS-aluminum-adjacent).
- Keep it simple enough to survive at 16×16 (Finder list view) — this is the real constraint. If the two-device composition doesn't hold up at 16px, fall back to a single closed/dark-screened laptop silhouette with a small light accent, no external monitor.

Practical note: you don't need a designer for v1 — SF Symbols + a few minutes in an icon-composer tool (Icon Composer, or even Keynote export to PNG at required sizes) gets a clean-enough result for a free indie utility. Revisit polish only if the app gets traction.

## 3. In-app design

Current `MenuBarView.swift` is a plain SwiftUI `VStack` — functional, no visual identity. Suggested refinement, still trivial to build in SwiftUI:

- **Header row:** small icon (the app icon, static) + status text that mirrors the current state in words, not just the button label — e.g. "Internal display is off" / "Internal display is on" — so the state is legible without reading the button.
- **Primary action button:** keep it a single, unambiguous verb — "Turn Off Built-in Display" / "Turn On Built-in Display" — this is already right, don't add icon-only buttons here; the whole point of this app is that the action is never ambiguous.
- **Status color, used sparingly:** a small dot or text tint (amber/dim when off, default/neutral when on) next to the status line — one accent color only, reuse the same accent as the app icon's monitor glow for consistency.
- **Error state:** already present (`viewModel.lastError`) — keep it visible but secondary (caption, muted), exactly as now.
- **Settings section:** "Launch at Login" toggle — keep as-is, it's already correctly scoped as a toggle, not a separate settings window (no need for one at this feature count).
- **Quit:** keep at the bottom, standard placement.

Don't add a preferences window, tabs, or onboarding flow for v1 — the entire feature surface is one toggle and one setting. A multi-screen settings UI would be over-building for what this app does.

## 4. Distribution & positioning

- **Free, direct distribution**, notarized DMG via GitHub Releases — matches PRD §6/§8 (no App Store, private API rules that out anyway). `README.md` and `dmg.sh` are built; DMG packaging is scripted but unsigned/unnotarized (notarization needs Apple ID credentials — deliberately a manual step, documented in `dmg.sh`'s header comment).
- **Landing page:** deferred — needs a real screenshot/GIF and app icon (§2) to be worth building; a placeholder page would just need redoing once those exist. Not built yet. One page, not a site, when it happens — headline stating the one thing it does, one screenshot/GIF of the menu bar toggle in action, a Download button linking the latest GitHub release, a link to source. No pricing section, no feature grid — there's one feature.
- **Launch channels, in order of expected signal quality for this niche:**
  1. Show HN — this audience is exactly the target user (developer, external monitor, wants lid open).
  2. r/macapps
  3. A short post/thread on X/Twitter from your own account, since the target user is literally "a developer/power user" like the PRD's target-user description.
- **Messaging line:** "Turn off your MacBook's built-in display without closing the lid — keyboard, trackpad, and speakers keep working." Lead with the differentiator vs. real clamshell mode (peripherals keep working), not with the mechanism (private API is an implementation detail, not a selling point).
- **Trust/safety messaging matters more than usual here** because the failure mode (private API breaks, or user gets a black screen) is scary for a niche audience that's often been burned by Lunar/BetterDisplay-style bundleware — the README/landing page should explicitly state the safety nets already built (auto-restore on external-display unplug, crash recovery, sleep/wake restore) since PRD §5 already treats these as core, not nice-to-have.

## 5. Roadmap after MVP

Sequenced by what's already flagged as out-of-scope-for-now in PRD §6, ordered by expected value for the smallest added effort:

1. **v1.0** — ship current MVP as-is (toggle, safety nets, launch-at-login). This is the whole product; don't hold the release for anything below.
2. **v1.1 — global hotkey.** Explicitly called out as "nice-to-have, not MVP" in the PRD — cheapest next win since the toggle logic already exists; this is just an input binding.
3. **v1.2 — solo-mode for multi-external-display setups** (choose exactly one of N displays to keep active). Only worth building if user reports show people actually run 2+ externals — don't build speculatively.
4. **Later, only if requested — software-blackout overlay for the no-external-display case.** PRD §9 flags this as an open question, not a commitment. This is a materially different mechanism (an overlay window, not a display-config API call) — treat it as a new feature investigation, not a natural v1.x increment.

Do not build 2–4 before shipping v1.0. The MVP as specced is already a complete, useful product.
