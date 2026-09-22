# Roadmap, Distribution & Positioning

> Migrated from the former repo-root `PRODUCT_PLAN.md` §4–5.

## Roadmap after MVP

Sequenced by what's already flagged as out-of-scope-for-now in the PRD, ordered by expected value for the smallest added effort:

1. **v1.0** — ship current MVP as-is (toggle, safety nets, launch-at-login). This is the whole product; don't hold the release for anything below.
2. **v1.1 — global hotkey.** Explicitly called out as "nice-to-have, not MVP" in the PRD — cheapest next win since the toggle logic already exists; this is just an input binding.
3. **v1.2 — solo-mode for multi-external-display setups** (choose exactly one of N displays to keep active). Only worth building if user reports show people actually run 2+ externals — don't build speculatively.
4. **Later, only if requested — software-blackout overlay for the no-external-display case.** Flagged as an open question, not a commitment. This is a materially different mechanism (an overlay window, not a display-config API call) — treat it as a new feature investigation, not a natural v1.x increment.

Do not build 2–4 before shipping v1.0. The MVP as specced is already a complete, useful product.

## Distribution & positioning

- **Free, direct distribution**, notarized DMG via GitHub Releases — matches the PRD's permanent no-App-Store decision (private API rules it out anyway). `README.md` and `dmg.sh` are built; DMG packaging is scripted but unsigned/unnotarized (notarization needs Apple ID credentials — deliberately a manual step, documented in `dmg.sh`'s header comment).
- **Landing page:** deferred — needs a real screenshot/GIF and app icon to be worth building; a placeholder page would just need redoing once those exist. Not built yet. One page, not a site, when it happens — headline stating the one thing it does, one screenshot/GIF of the menu bar toggle in action, a Download button linking the latest GitHub release, a link to source. No pricing section, no feature grid — there's one feature.
- **Launch channels, in order of expected signal quality for this niche:**
  1. Show HN — this audience is exactly the target user (developer, external monitor, wants lid open).
  2. r/macapps
  3. A short post/thread on X/Twitter from your own account, since the target user is literally "a developer/power user" like the PRD's target-user description.
- **Messaging line:** "Turn off your MacBook's built-in display without closing the lid — keyboard, trackpad, and speakers keep working." Lead with the differentiator vs. real clamshell mode (peripherals keep working), not with the mechanism (private API is an implementation detail, not a selling point).
- **Trust/safety messaging matters more than usual here** because the failure mode (private API breaks, or user gets a black screen) is scary for a niche audience that's often been burned by Lunar/BetterDisplay-style bundleware — the README/landing page should explicitly state the safety nets already built (auto-restore on external-display unplug, crash recovery, sleep/wake restore) since the PRD already treats these as core, not nice-to-have.
