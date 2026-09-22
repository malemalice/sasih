# Sasih (`mac-app-blackout`) — Agent Entry Point

> Single-repo workspace. This file is both the workspace master entry point **and** the repo entry point — read it completely before acting.
>
> **Read order:** this `AGENTS.md` → select your role → `docs/agents/<role>.md` → `docs/index.md` → navigate to only the sub-doc relevant to your task → check `docs/exec-plans/active/` for an existing plan (create one for complex tasks) → read `docs/QUALITY_SCORE.md` before touching any domain → then and only then explore project files for anything still unclear. Do not re-read files you have already read in this session.

## What this is

Sasih is a free, single-purpose macOS menu-bar app that turns off a MacBook's built-in display while the lid stays open (keyboard, trackpad, Touch Bar, and speakers keep working). It uses the private SkyLight symbol `SLSConfigureDisplayEnabled` resolved at runtime — no public API can do this. The product's top-priority correctness requirement is: **never strand the user with a black screen and no way back.**

## Workspace layout

```
mac-app-blackout/                 ← the workspace AND the only repo
  ├── Sources/SasihCore/          ← pure display logic (no AppKit/SwiftUI, injected protocols)
  ├── Sources/SasihApp/           ← menu-bar app shell (SwiftUI MenuBarExtra + AppKit delegate)
  ├── Sources/SasihSpike/         ← throwaway private-API spike CLI (not shipped)
  ├── Tests/                      ← SasihCoreTests, SasihAppTests (swift-testing, @Test)
  ├── docs/                       ← canonical knowledge base (read this first; see docs/index.md)
  ├── PRD.md / TRD.md / PRODUCT_PLAN.md  ← redirect stubs → docs/
  └── test.sh · build.sh · dmg.sh ← the whole toolchain (CLT-only machine, no Xcode)
```

## Repo registry

| Folder | Role | Stack | Entry | Owns |
|---|---|---|---|---|
| `.` (mac-app-blackout) | macOS app (single repo) | Swift 6 / SwiftPM, macOS 13+, SwiftUI + AppKit, zero third-party deps | this file | Display safety logic, menu-bar UI, private-API integration, build/release pipeline |

There are no sibling repos. Cross-repo playbooks do not apply; the equivalents here are the **contract** flows (private SkyLight ABI, GitHub Releases API, persisted state) — see `docs/playbooks/contract-change.md`.

## How to operate

1. Read this file completely before taking any action.
2. Classify the task with the table below and select your role from the agent table.
3. Read your role file in `docs/agents/` — do not skip it.
4. For complex tasks (>3 files, >1 role, or any change to lifecycle/safety-net/private-API paths), create an exec-plan from `docs/exec-plans/active/_template.md` **before** writing code.
5. Follow the matching playbook in `docs/playbooks/`.
6. Execute. Explore project files only for things not covered by the instruction system.
7. Close out: update the docs you invalidated, run `./test.sh`, and record any new debt in `docs/exec-plans/tech-debt-tracker.md`.

## Agent table

| Agent file | Role | When to use |
|---|---|---|
| `docs/agents/macos-engineer.md` | macOS Engineer | Any Swift code change: core logic, app shell, private API, tests |
| `docs/agents/qa-engineer.md` | QA Engineer | Test coverage, test review, manual hardware-matrix runs and sign-off |
| `docs/agents/release-engineer.md` | Release Engineer | Version bumps, signing, notarization, DMG, GitHub Releases, update check |
| `docs/agents/designer.md` | Designer | Menu-bar menu UI, icon assets, copy that carries state, design-system updates |
| `docs/agents/product-manager.md` | Product Manager | Scope, requirements, roadmap, priorities, open questions |

## Task classification

| Task type | Signals | Primary agent | Supporting agents | Typical blast radius |
|---|---|---|---|---|
| Core logic change (guards, state, persistence) | "display", "state", "restore", "persist" | macOS Engineer | QA | `SasihCore` + tests |
| App lifecycle / safety-net change | "wake", "sleep", "reconfig", "timer", "callback" | macOS Engineer | QA (mandatory manual matrix) | `SasihApp` + `SasihCore` |
| Private API / symbol work | "SkyLight", "SLS", "CGS", "dlopen" | macOS Engineer | QA (hardware run mandatory) | `SasihCore/PrivateAPI` |
| UI / copy change | "menu", "icon", "label", "toggle" | Designer | macOS Engineer | `SasihApp` UI + `design-system/` |
| Bug fix | "broken", "wrong", "stuck", "doesn't" | macOS Engineer | QA | usually small |
| Release | "bump", "release", "dmg", "notarize" | Release Engineer | QA | `Info.plist` + scripts + GitHub |
| Refactor | "clean up", "extract", "restructure" | macOS Engineer | QA | scoped, exec-plan required |
| Requirements / scope | "should we", "prioritise", "next" | Product Manager | — | `docs/prd/` only |
| Contract change (SkyLight / GitHub API / persisted state) | "symbol", "endpoint", "release tag", "UserDefaults key" | macOS Engineer | PM, QA, Release Engineer | `docs/api-contracts/` or `docs/erd/` **first** |

## Sub-agent orchestration

**Single agent** when the task is unambiguous, one role, <3 files, no safety-net/private-API path.

**Multiple agents** when the task spans roles or needs sequential gates. Standard flow for a feature that reaches the private API or lifecycle paths:

1. **PM** — confirm scope against `docs/prd/features.md` / `open-questions.md`; output acceptance criteria.
2. **macOS Engineer** — if a contract is touched, update `docs/api-contracts/` or `docs/erd/` **before** code; implement; keep `SasihCore` UI-free.
3. **Designer** — if user-visible, specify against `docs/design-system/` and keep state legible without colour alone.
4. **QA** — unit tests via `./test.sh`; then the hardware-matrix scenarios from `docs/playbooks/hardware-verification.md` that the change touches. QA sign-off overrides the engineer's "works on my machine".
5. **Release Engineer** — only when shipping: `docs/playbooks/release.md`, version bump in both Info.plist keys, notarize + staple, publish.

Parallelise independent read-only work (e.g. engineer maps code while PM checks scope); never parallelise hardware verification with code changes on the same machine.

**Handoff protocol** — each agent, when finished, reports: what was done · files touched · what the next agent needs · open questions · which docs were updated.

**Conflict resolution**

| Dimension | Owner | Overrides |
|---|---|---|
| Product scope & priority | Product Manager | All others |
| Contract shape (SkyLight usage, API usage, persisted keys) | macOS Engineer, with `docs/api-contracts/` updated first | Other implementers |
| Visual design & user-facing copy | Designer | Engineer |
| Technical feasibility within the repo | macOS Engineer | PM, Designer |
| Safety-net behaviour ("never strand the user") | **Non-negotiable — no role may override**; escalate to the user | All |
| Test coverage & manual-matrix sign-off | QA Engineer | Engineer |
| Release readiness | Release Engineer | All others at ship time |

## Reference docs

| Task type | Read first |
|---|---|
| Any task | `docs/index.md` — then only the sub-file you need |
| Feature / bug | `docs/prd/features.md`, `docs/trd/mac-app-blackout/stack-architecture.md` |
| Core logic | `docs/trd/mac-app-blackout/stack-architecture.md`, `docs/erd/relationships.md` |
| Persisted state | `docs/erd/entities.md`, `docs/erd/notes.md` |
| Private API / symbol | `docs/references/mac-app-blackout/skylight-private-api.md`, `docs/api-contracts/overview.md` |
| UI / icons / copy | `docs/design-system/index.md` → relevant sub-file |
| Release / updates | `docs/trd/mac-app-blackout/deployment.md`, `docs/api-contracts/endpoints.md` |
| Complex task | `docs/exec-plans/active/_template.md` — create the plan first |
| Any domain graded C or below | `docs/QUALITY_SCORE.md` — read before touching |

## Playbooks

| Task | Playbook |
|---|---|
| Feature flow | `docs/playbooks/feature-flow.md` |
| Bug fix | `docs/playbooks/bugfix-flow.md` |
| Refactor | `docs/playbooks/refactor-flow.md` |
| Contract change (SkyLight / GitHub API / persisted state) | `docs/playbooks/contract-change.md` |
| Release (bump → sign → notarize → DMG → GitHub) | `docs/playbooks/release.md` |
| Hardware verification (manual matrix) | `docs/playbooks/hardware-verification.md` |

## Hard rules (from the project owner — do not violate)

1. **Zero new dependencies** without explicit owner approval — no SwiftPM packages, no vendored code. System frameworks and bundled CLI tools only.
2. **`SasihCore` never imports AppKit or SwiftUI** and never touches real hardware outside the injected protocols.
3. **Never weaken or bypass a safety net** for convenience: external-display guards, last-active-display guard, emergency restore, restore-on-launch, restore-before-quit, wake restoration. These are the product.
4. **Any change to the private API path requires a hardware-verification plan** (`docs/playbooks/hardware-verification.md`) — unit tests with fakes cannot prove real behaviour.
5. **Never publish a release without explicit owner approval.** No exceptions.
6. **No telemetry, analytics, or network calls** beyond the user-triggered GitHub update check.
7. **No secrets in the repo** or in the app bundle; signing credentials live only in the release engineer's environment.
8. **Never hand-edit build outputs** (`Sasih.app/`, `Sasih.dmg`) — they are generated by `build.sh` / `dmg.sh`.
9. **User-facing strings in English**, sentence case, plain language (see `docs/design-system/components.md`).
10. **Docs are part of done:** a change that invalidates a canonical doc updates it in the same change (`docs/` is the single source of truth).

## Core principle

Read the instruction system first. Explore project files second. Generate code last. Every decision must be traceable to a sub-file under `docs/prd/`, `docs/trd/`, `docs/erd/`, `docs/design-system/`, or `docs/api-contracts/`; complex tasks trace to an exec-plan in `docs/exec-plans/active/`.
