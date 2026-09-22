# Playbook — Bug Fix

Use for anything broken. If the fix touches >3 files or spans roles, create an exec-plan first. If it changes a contract (persisted key, SkyLight usage, release/tag discipline), use [contract-change.md](./contract-change.md) as well.

**Triage first:** does the bug involve a stuck/black display, a failed restore, or a missed safety net? If yes — stop and treat it as severity High. The product's top requirement is "never strand the user". Reproduce safely before anything else: confirm the manual recovery path from `docs/playbooks/hardware-verification.md` (reboot always clears the disabled state).

1. **Reproduce.** Find deterministic steps. For timing-dependent paths, capture the unified log while reproducing:
   ```bash
   log stream --predicate 'subsystem == "com.adaptivid.sasih"' --level info
   ```
   (Every decision point logs with `privacy: .public` precisely for this.)
2. **Expected behaviour.** Read `docs/trd/mac-app-blackout/stack-architecture.md` §6–§8 (responsibilities + event wiring) and `docs/erd/relationships.md` (invariants). A fix must restore the invariant, not paper over it.
3. **Data-related?** If the bug involves persisted state (`IsInternalDisplayOff`, `BackupInternalDisplayID`, `AutoRevertInternalOffOnReconnect`), read `docs/erd/entities.md` + `notes.md` (failure-mode table) before touching `DisplayIDStore`.
4. **External contract?** If the bug involves the update check or the private symbol, read `docs/api-contracts/errors.md` — the failure taxonomy defines what "fixed" means.
5. **Isolate.** Find the smallest change that causes it. Do not refactor adjacent code while fixing.
6. **Fix.** Minimal diff. If it touches a safety net, write down (in the commit/plan) which invariant was broken and why the fix restores it.
7. **Verify.** Add a regression test when the path is automatable (pure logic → unit test with fakes). If the path is hardware-dependent, re-run the affected rows of `docs/playbooks/hardware-verification.md` on real hardware — do not mark it fixed from code review.
8. **Regression check.** `./test.sh` fully green; re-check the neighbouring safety-net logic for the same class of bug (e.g. same timer/callback handling elsewhere).
9. **Document.** If the bug revealed a doc gap (a missing invariant, an unlisted failure mode, a matrix row not covered), update that doc in the same change. Add recurring/severe debt to `docs/exec-plans/tech-debt-tracker.md`.
10. **Quality score.** If a domain's health changed (gap found, coverage added), update `docs/QUALITY_SCORE.md`.
