# State & Data Model — Index

> Status: Authored 2026-09-22. This product has **no database and no server side**;
> this doc type covers the persisted and in-memory state that must stay consistent
> across launches, crashes, sleep/wake, and display reconfiguration.

| File | Contents |
|---|---|
| [entities.md](./entities.md) | Persisted keys, files, and runtime state fields |
| [relationships.md](./relationships.md) | State machine (internal display on/off, fallback flag) |
| [notes.md](./notes.md) | Storage locations, defaults, privacy, failure modes |
| [repo-mapping.md](./repo-mapping.md) | Where each entity lives in code (and in tests) |
