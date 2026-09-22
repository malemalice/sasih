# Technical Requirements — Index

> Status: Migrated 2026-09-22 from the former repo-root `TRD.md` (now a redirect stub).
> This is a single-repo product, so there is one sub-folder.

| Repo | Folder | Stack-architecture | Constraints | Deployment | Decisions |
|---|---|---|---|---|---|
| mac-app-blackout | [mac-app-blackout/](./mac-app-blackout/) | [stack-architecture.md](./mac-app-blackout/stack-architecture.md) | [constraints-integrations.md](./mac-app-blackout/constraints-integrations.md) | [deployment.md](./mac-app-blackout/deployment.md) | [decisions.md](./mac-app-blackout/decisions.md) |

## Verification & testing plan (moved)

The former TRD §8 (unit tests, manual hardware matrix, compatibility checks, recovery path, pre-release checklist) lives in the playbooks because it is an execution procedure, not a static spec:

- [../playbooks/hardware-verification.md](../playbooks/hardware-verification.md) — manual test matrix (§8.0–§8.3)
- [../playbooks/release.md](../playbooks/release.md) — pre-release checklist, signing, DMG, notarization (§8.4–§8.5)

## Cross-repo TRD topics

N/A — single-repo workspace. See [shared-decisions.md](./shared-decisions.md) for the record.
