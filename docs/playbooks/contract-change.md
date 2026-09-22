# Playbook — Contract Change

Use when a change touches any of the three external-facing contracts. Review first: **`docs/api-contracts/` and `docs/erd/` are the source of truth; they are updated before code, always.**

| Contract | Defined in | Change examples |
|---|---|---|
| Private SkyLight ABI | `docs/api-contracts/overview.md` (A), `endpoints.md` (A.1), `references/mac-app-blackout/skylight-private-api.md` | new symbol name, changed call signature, new transaction wrapper, fallback-order change |
| GitHub Releases API usage | `docs/api-contracts/overview.md` (B), `endpoints.md` (B.1) | endpoint/headers change, new fields consumed, tag/asset discipline change |
| Persisted state | `docs/erd/entities.md`, `notes.md`, `repo-mapping.md` | add/rename/remove a UserDefaults key or backup file, change defaults, change write timing |

0. **Always create an exec-plan** in `docs/exec-plans/active/`. Name the contract(s) touched.
1. **Identify the change surface.** Write the exact diff to the contract: old shape → new shape, and why.
2. **Update the source-of-truth doc first:**
   - SkyLight / GitHub API → edit the relevant `docs/api-contracts/` sub-file(s).
   - Persisted key → edit `docs/erd/entities.md` + `repo-mapping.md` + `notes.md` (failure modes).
   - Log an entry in `docs/api-contracts/changes.md` (date, contract, change, breaking?).
3. **Assess breakingness and blast radius.**
   - Persisted key renamed → old installs read the new key as absent; check every reader's default and the "safe direction" table in `docs/erd/notes.md`.
   - SkyLight symbol/fallback change → every display path is affected; hardware verification is mandatory regardless of how small the diff looks.
   - GitHub API/tag discipline → update-check behavior for already-shipped versions; consider keeping backward compatibility with old tags.
4. **Implement** the code change (macOS Engineer) against the updated contract; tests with fakes first where possible.
5. **Verify:** `./test.sh` (symbol-resolution fallback tests, ID-store round-trip, guards, state diff must all still pass).
6. **Hardware verification (mandatory if the SkyLight contract or any display path changed):** run the applicable rows of `docs/playbooks/hardware-verification.md`. Unit tests with fakes cannot prove real behaviour — this is hard rule 4 in `AGENTS.md`.
7. **Update `changes.md` with the final shipped change** and the date (change entries are drafted in step 2, finalized here).
8. **Release coordination (Release Engineer, if shipping):** confirm tag/version discipline still holds; if the update-check contract changed, verify `releases/latest` returns the expected shape before publishing.
9. **Quality score + debt:** update `docs/QUALITY_SCORE.md` for any domain affected; record new debt.
10. **Move the exec-plan to `docs/exec-plans/completed/`.**
