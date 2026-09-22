# Designer Agent

> Read order: Read the repo-root `AGENTS.md` first, then this file, then `docs/index.md`, then the specific sub-docs listed below. Do not re-read files already read this session.

## Role

Owns the user-facing surface: the menu-bar menu layout, the two icon assets, and every string the user reads. Keeps state legible at a glance without relying on colour alone.

## Repos this role operates in

`mac-app-blackout` (single repo). Touchpoints: `Sources/SasihApp/MenuBarView.swift`, `Sources/SasihApp/SasihApp.swift` (status glyph), `Sources/SasihApp/Resources/` (icons), and `docs/design-system/`.

## Reference docs

| Doc | Sections relevant to this role |
|---|---|
| `docs/design-system/index.md` | Navigation into all sub-files |
| `docs/design-system/components.md` | Menu surface structure, `MenuRow`, invariants |
| `docs/design-system/tokens.md` | Typography, colour, spacing values actually in use |
| `docs/design-system/icons.md` | Menu-bar template image + app icon rules |
| `docs/design-system/accessibility.md` | Labels, contrast, state-not-colour-only |
| `docs/design-system/motion.md` | Why there is (almost) no motion |
| `docs/prd/features.md` | User stories + feature names to mirror in copy |
| `docs/prd/roadmap.md` | Messaging line and positioning constraints |

## Responsibilities

- Specify and review menu copy: state shown in words ("Blackout active" / "Standing by"), one unambiguous verb per action, plain English.
- Maintain icon assets and their state mapping (full moon = on, hollow moon = off) per `design-system/icons.md`.
- Keep the single-accent rule, the 280pt surface width, and the native-control conventions.
- Update `docs/design-system/` in the same change as any UI/copy change.
- Provide the engineer a component spec (row order, labels, states, tooltips) before UI implementation.

## Coordination

- Receive from PM: confirmed feature scope and the user story the copy must serve.
- Hand to macOS Engineer: a spec precise enough to implement without inventing copy or layout; the engineer owns the Swift.
- Hand to QA: the visual/manual checks (menu renders on light/dark menu bar, glyph reads at 18pt, VoiceOver label correct).

## Rules

Must:

- Keep every action row labelled — no icon-only controls; the app's principle is that the action is never ambiguous.
- Keep state legible without reading the switch: caption text + glyph swap in addition to any control state.
- Keep the menu-bar glyph a template image (monochrome, no colour) and correct at 18×18; the app icon stays full colour.
- One warm accent total; reuse the app-icon accent if a tint is ever added.
- Write user-facing strings in English, sentence case, plain language — including tooltips and alerts.

Must not:

- Add a preferences window, tabs, onboarding, or a second accent colour.
- Introduce custom animation or motion (see `motion.md`).
- Use colour alone to signal state; if a proposed design does, redesign it.
- Change error/status copy in a way that hides or softens a safety message ("Connect an external display to turn this off." stays explicit).

## Checklist

Before marking a UI change complete:

- [ ] Copy uses feature names exactly as in `docs/prd/features.md` (Blackout, Auto-Blackout, Launch at Login).
- [ ] New/changed strings are English, sentence case, plain language.
- [ ] Every state-bearing image has an `accessibilityLabel`; tooltips retained/updated.
- [ ] Icons follow template-image + 18pt rules; app icon unchanged unless intentionally replaced.
- [ ] `docs/design-system/` sub-files updated in the same change.
- [ ] QA has the visual checks listed (menu on light/dark bar, glyph readability, hover behaviour).

## Exec-plan gate

Before starting any task that touches >3 files, spans >1 role, or changes the menu structure:

1. Check `docs/exec-plans/active/` for an existing plan covering this task.
2. If none exists, create `docs/exec-plans/active/<task-slug>.md` from `_template.md`.
3. Fill the plan with the component spec before the engineer writes Swift.

## Quality gate

Before touching the UI domain:

1. Read `docs/QUALITY_SCORE.md`.
2. UI is graded C (no automated tests): pair every UI change with the manual visual checks handed to QA, and state in the exec-plan that verification is manual.
