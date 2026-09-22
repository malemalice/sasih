# Playbooks — Index

> Step-by-step execution guides. Pick the playbook that matches the task before writing
> anything; each one references the roles and docs that gate it.

| Task | Playbook | Roles involved |
|---|---|---|
| Feature work (single repo) | [feature-flow.md](./feature-flow.md) | PM → macOS Engineer → Designer (if visible) → QA |
| Bug fix | [bugfix-flow.md](./bugfix-flow.md) | macOS Engineer → QA |
| Refactor | [refactor-flow.md](./refactor-flow.md) | macOS Engineer → QA |
| Contract change (SkyLight ABI / GitHub API / persisted state) | [contract-change.md](./contract-change.md) | macOS Engineer (+ PM/QA/Release as needed) |
| Release (bump → sign → notarize → DMG → GitHub) | [release.md](./release.md) | Release Engineer (QA gate, owner approval) |
| Hardware verification (manual matrix) | [hardware-verification.md](./hardware-verification.md) | QA (mandatory for lifecycle/private-API paths) |

## Cross-repo playbook

Not applicable — this workspace is a single repo. The nearest equivalent risk is an
external contract change; use [contract-change.md](./contract-change.md).
