# Playbook — Refactor

Use for structural change with no intended behaviour change. Refactors **always** qualify for an exec-plan.

0. **Exec-plan.** Create `docs/exec-plans/active/<task-slug>.md` from `_template.md`. State explicitly: which public surfaces must not change, and the test evidence you'll use to prove behaviour is preserved.
1. **Scope check.** Read `docs/trd/mac-app-blackout/stack-architecture.md` §4–§5. The refactor must move code *towards* those rules (e.g. less UI in Core, more injected protocols), never away.
2. **Public-surface check.** Anything in `SasihCore`'s public API, the injected protocols, the persisted keys, or the private-API call shape is a contract (see `docs/api-contracts/` + `docs/erd/`). Changing those is not a pure refactor — use [contract-change.md](./contract-change.md).
3. **Read before writing.** Read every file in scope fully before editing; understand the *why* comments — they encode timing/safety reasoning that a naive cleanup can destroy.
4. **Define the frozen surface.** List what must not change: safety-net semantics, transaction failure discipline, logging contract (`privacy: .public`), UI copy, persisted key names.
5. **Increments.** Smallest possible steps. `./test.sh` after each increment. No "big bang" edits.
6. **Preserve failure behaviour.** Any refactor of `PrivateAPIDisplayConfigurer` / `DisplayManager` must keep: cancel-on-error, no optimistic state writes, `lastError` semantics.
7. **Update consumers in the same change** (view model, app delegate, tests) — no dangling old APIs.
8. **Docs.** If the structure changed, update `docs/trd/mac-app-blackout/stack-architecture.md` §4 module layout / §5 rules. If nothing structural changed, say so in the exec-plan close-out.
9. **Verify.** `./test.sh` green; no type/lint issues (no linters configured — compile is the bar). If lifecycle or private-API code was moved (even without behaviour change), run the affected hardware-matrix rows: moved code is unverified code.
10. **Quality score.** Update `docs/QUALITY_SCORE.md` if coverage/health changed. Move the exec-plan to `completed/`.
