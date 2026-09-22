# Documentation Index — Sasih (`mac-app-blackout`)

> Read this file first to navigate the canonical knowledge base.
> Open only the sub-doc relevant to your current task. Do not read entire directories.

## Workspace shape

Single-repo workspace: this repo **is** the workspace. There are no sibling code repos.
See `AGENTS.md` at the repo root for the routing table, read-order chain, and gates.

## Canonical docs

| Type | Index | Purpose |
|---|---|---|
| Product Requirements | [prd/index.md](./prd/index.md) | Problem, goals, personas, features, roadmap, open questions |
| Technical Requirements | [trd/index.md](./trd/index.md) | Stack, architecture, private-API constraints, deployment, decisions |
| Entity Relationship | [erd/index.md](./erd/index.md) | Persisted + runtime state model (no database; UserDefaults + backup file) |
| Design System | [design-system/index.md](./design-system/index.md) | Menu-bar icon, app icon, tokens, components, accessibility |
| API Contracts | [api-contracts/index.md](./api-contracts/index.md) | GitHub Releases API + private SkyLight symbol contract |

## Agent roles

| Type | Index | Purpose |
|---|---|---|
| Agent roles | [agents/index.md](./agents/index.md) | Role definitions, responsibilities, rules |
| Playbooks | [playbooks/index.md](./playbooks/index.md) | Step-by-step task execution guides |

## Operations

| Type | Location | Purpose |
|---|---|---|
| Execution Plans | [exec-plans/](./exec-plans/) | Active and completed task plans |
| Tech Debt | [exec-plans/tech-debt-tracker.md](./exec-plans/tech-debt-tracker.md) | Running debt list |
| Quality Score | [QUALITY_SCORE.md](./QUALITY_SCORE.md) | Domain health and test coverage |

## External references

| Type | Index | Purpose |
|---|---|---|
| Library / framework docs | [references/index.md](./references/index.md) | LLM-friendly summaries of key dependencies: Apple frameworks, private SkyLight API, CLI tools, GitHub API |

## Navigation rules

1. Identify your **task type** (feature / bug / design / release / data / docs)
2. Open the relevant doc type index above
3. From the index, open only the sub-file that covers your task
4. Do not read sub-files unrelated to your current task
5. Read [QUALITY_SCORE.md](./QUALITY_SCORE.md) before touching a graded domain
6. Any task touching >3 files or >1 role needs an exec-plan in `exec-plans/active/`
