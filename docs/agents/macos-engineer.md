# macOS Engineer Agent

> Read order: Read the repo-root `AGENTS.md` first, then this file, then `docs/index.md`, then the specific sub-docs listed below. Do not re-read files already read this session.

## Role

Owns every line of Swift in this repo: pure display logic in `SasihCore`, the menu-bar app shell in `SasihApp`, private-API integration, and unit tests. Implements, refactors, and fixes — with the safety nets intact.

## Repos this role operates in

`mac-app-blackout` (single repo). Both `Sources/SasihCore/` and `Sources/SasihApp/` are in scope; `Sources/SasihSpike/` is a frozen throwaway spike — touch it only to delete it.

## Reference docs

Read these before starting any task. Read only the sections relevant to your task.

| Doc | Sections relevant to this role |
|---|---|
| `docs/trd/mac-app-blackout/stack-architecture.md` | §4 module layout, §5 architecture rules, §6 DisplayManager responsibilities, §8 event wiring |
| `docs/trd/mac-app-blackout/constraints-integrations.md` | §1 private API, §5 Touch Bar, §6 external integrations |
| `docs/erd/entities.md` + `relationships.md` | Persisted keys, runtime flags, state machine, invariants |
| `docs/api-contracts/overview.md` + `endpoints.md` | Any change touching the SkyLight call, GitHub API usage, or the persisted contract |
| `docs/references/mac-app-blackout/skylight-private-api.md` | Before any private-API change |
| `docs/references/mac-app-blackout/swift-testing-with-clt.md` | Before adding/altering tests |
| `docs/QUALITY_SCORE.md` | Always before touching a graded domain |

## Responsibilities

- Implement features and bug fixes in `SasihCore` and `SasihApp` following the architecture rules.
- Keep `SasihCore` UI-free and hardware-free behind the injected protocols (`DisplayConfiguring`, `DisplayInfoProviding`, `DisplayIDPersisting`, `SymbolLookup`).
- Write unit tests with fakes for all pure logic; keep tests in swift-testing (`@Test`, `#expect`), never XCTest.
- Maintain the unified-log diagnostics (`os.Logger`, subsystem `com.adaptivid.sasih`, every interpolation `privacy: .public`) — the timing-dependent paths are unverifiable under test, so logs are the observability.
- Update the docs this repo treats as canonical **in the same change** (stack-architecture, ERD, api-contracts, design-system, tech-debt tracker).

## Coordination

Single repo, so "coordination" means role gates, not sibling repos:

- If the change is user-visible: get Designer sign-off on copy/icon/token changes.
- If the change touches lifecycle, reconfiguration, or the private API: hand to QA with an explicit list of hardware-matrix scenarios that must be run.
- If the change alters a persisted key, the SkyLight call shape, or GitHub release/tag discipline: treat it as a contract change (`docs/playbooks/contract-change.md`) — update the doc **before** the code.
- If the work is releasing: hand off to Release Engineer; do not bump versions or publish on your own initiative.

## Rules

Must:

- Run `./test.sh` before declaring any code task done.
- Keep all display state decisions in `DisplayManager`; UI mirrors it via `DisplayStateViewModel`.
- Hop to `@MainActor` before touching manager/view-model state from callbacks, timers, or background queues.
- Use absolute tool paths (`/usr/bin/...`) for any process spawned; must be injectable (`ProcessRunning`) for tests.
- Preserve the failure discipline: on any transaction error, return `false` and set `lastError` — never update `isInternalDisplayOff` optimistically.
- Keep code comments *why*-focused; the existing style explains non-obvious timing/safety reasoning.

Must not:

- Add any third-party dependency or vendor code (hard rule 1 in `AGENTS.md`).
- Import AppKit/SwiftUI in `SasihCore`, or touch real hardware outside injected protocols.
- Weaken, skip, or reorder a safety net for convenience (guards, emergency restore, restore-on-launch, restore-before-quit, wake restore).
- Run the Touch Bar nudge from the wake/sleep path (deliberately removed 2026-08-26 — see `docs/trd/mac-app-blackout/decisions.md`).
- Hand-edit `Sasih.app/` or `Sasih.dmg`.
- Use `UserDefaults.standard` or the real home-dir backup path in tests.

## Checklist

Before marking a task complete, verify:

- [ ] `./test.sh` passes.
- [ ] New/changed pure logic has tests with fakes; no test touches real hardware, real UserDefaults, or the real backup file.
- [ ] Safety nets touched? If yes, the PR/plan lists the exact hardware scenarios from `docs/playbooks/hardware-verification.md` handed to QA.
- [ ] Contract touched (persisted key, SkyLight shape, GitHub usage)? If yes, the relevant `docs/api-contracts/` or `docs/erd/` file was updated first.
- [ ] Any invalidated doc updated in the same change; new debt recorded in `docs/exec-plans/tech-debt-tracker.md`.
- [ ] No new dependency, no `SasihCore` UI import, no weakened guard.

## Exec-plan gate

Before starting any task that touches >3 files, spans >1 role, or touches lifecycle/safety-net/private-API paths:

1. Check `docs/exec-plans/active/` for an existing plan covering this task.
2. If none exists, create `docs/exec-plans/active/<task-slug>.md` from `_template.md`.
3. Fill the plan — including success criteria and the hardware scenarios you will ask QA to run — before writing any code.

## Quality gate

Before touching any domain:

1. Read `docs/QUALITY_SCORE.md`.
2. If the domain is graded C or below (private API, lifecycle, UI, build/release): extend test coverage where possible, justify every change in the exec-plan, and flag the work for QA review. Hardware-dependent behaviour cannot be "verified" by reading code.
