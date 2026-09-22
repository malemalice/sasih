# Playbook — Feature Flow (single repo)

Use for any new capability or user-visible change. For a change to the private API, persisted keys, or GitHub release/tag usage, switch to [contract-change.md](./contract-change.md) first.

0. **Exec-plan check.** Read `docs/exec-plans/active/`. If none covers the task and it touches >3 files, spans >1 role, or touches lifecycle/safety-net paths, create one from `_template.md` before writing code.
1. **Scope (PM).** Confirm the feature exists in `docs/prd/features.md` (or `roadmap.md`); write acceptance criteria as observable behaviour. If it's not in the PRD, add it (or log it in `open-questions.md`) before proceeding.
2. **State/persistence check (Engineer).** Compare the feature against `docs/erd/entities.md` and `relationships.md`. If it adds/changes a persisted key or a state transition, this is a contract change — update the ERD **first**.
3. **Design check (Designer, if UI).** Reuse what exists in `docs/design-system/components.md`; write the component spec (row order, labels, states, tooltips) before Swift is written.
4. **Architecture check (Engineer).** Read `docs/trd/mac-app-blackout/stack-architecture.md` §5; confirm the change respects `SasihCore` purity and the injected-protocol boundary.
5. **Implement (Engineer).** Smallest coherent change; tests alongside code (swift-testing, fakes); keep safety nets intact; log new decision points with `privacy: .public`.
6. **Unit verification (QA + Engineer).** `./test.sh` green; new pure logic has invariant tests; no test touches real hardware/UserDefaults/home files.
7. **Hardware verification (QA), if the feature touches lifecycle, reconfiguration, sleep/wake, the private API, or the menu bar UI.** Run the applicable rows of `docs/playbooks/hardware-verification.md` on real hardware; record macOS version + build.
8. **Docs close-out (all).** Update every doc the feature invalidated in the same change: `features.md`, `design-system/`, `erd/`, `api-contracts/`, plus `docs/exec-plans/tech-debt-tracker.md` for any new debt.
9. **Quality score (QA).** If coverage or health changed, update `docs/QUALITY_SCORE.md` with evidence.
10. **Done definition** (owner-agreed):
    - `./test.sh` passes;
    - relevant hardware-matrix rows run and recorded (or an explicit "no hardware impact" note);
    - acceptance criteria from step 1 demonstrably met;
    - all invalidated docs updated in the same change;
    - no new dependency, no `SasihCore` UI import, no weakened guard.
11. **Complete the exec-plan** (move to `docs/exec-plans/completed/`) if one was created.
