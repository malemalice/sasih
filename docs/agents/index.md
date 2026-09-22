# Agent Roles — Index

> Role behaviour lives **only** here. `AGENTS.md` routes; these files define. Edit a role
> here and every agent that reads it changes behaviour everywhere.
>
> Every role file follows the same structure: Role · Repos this role operates in ·
> Reference docs · Responsibilities · Coordination · Rules · Checklist · Exec-plan gate ·
> Quality gate.

| Agent file | Role | Primary owner of |
|---|---|---|
| [macos-engineer.md](./macos-engineer.md) | macOS Engineer | All Swift implementation: `SasihCore`, `SasihApp`, private-API integration, unit tests |
| [qa-engineer.md](./qa-engineer.md) | QA Engineer | Test strategy & coverage, manual hardware-matrix runs, verification sign-off |
| [release-engineer.md](./release-engineer.md) | Release Engineer | Versioning, signing, notarization, DMG, GitHub Releases, update-check health |
| [designer.md](./designer.md) | Designer | Menu surface, icon assets, user-facing copy, `docs/design-system/` |
| [product-manager.md](./product-manager.md) | Product Manager | Scope, features, roadmap, open questions, acceptance criteria |

## Selecting a role

Use the Task Classification table in the repo-root `AGENTS.md`. When a task spans roles, the
standard order for anything touching the private API or lifecycle paths is:
**PM → macOS Engineer → Designer (if visible) → QA → Release Engineer (if shipping)**.
