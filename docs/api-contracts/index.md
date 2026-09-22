# API Contracts — Index

> Status: Authored 2026-09-22. This repo has **no server**. "API contracts" here means the
> three interfaces the app depends on, each of which can break it silently if changed — so
> they get the same treatment as a backend↔frontend contract.

| Contract | Type | Producer | Consumer | Stability |
|---|---|---|---|---|
| Private SkyLight display-configuration symbol | in-process C ABI (dlopen) | Apple (undocumented) | `SasihCore.PrivateAPIDisplayConfigurer` | **Unstable by definition** — can change in any macOS release |
| GitHub Releases REST API | HTTPS/JSON over the network | GitHub / this repo's release process | `SasihApp.UpdateChecker` | Stable external API; our *usage* depends on our own release/tagging discipline |
| Persisted state (off-state flag, display ID, auto-revert preference) | in-process `UserDefaults` + backup file | `SasihCore.DisplayIDStore` | `DisplayManager` (reads/writes), `DisplayStateViewModel` (mirror), crash/wake safety nets | Shape stable (keys/types/defaults owned by `docs/erd/`); **write-semantics changes are contract changes** — log them in `changes.md` |

| File | Contents |
|---|---|
| [overview.md](./overview.md) | Transport, versioning policy for both contracts |
| [endpoints.md](./endpoints.md) | The exact call shapes used |
| [auth.md](./auth.md) | Auth model for both |
| [errors.md](./errors.md) | Error taxonomy and required handling |
| [changes.md](./changes.md) | Log of contract-affecting changes |
