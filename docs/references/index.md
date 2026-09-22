# External References

> Before calling any framework/API in this repo, find it below. If a reference file exists, read it first.
> Update when a dependency's behaviour changes or a new integration is added.

## How to populate

1. Prefer an official `llms.txt`/docs URL where one exists.
2. Otherwise summarise the specific APIs *this repo* calls, the patterns used here, and the gotchas.
3. Update "Last updated" in the table below when you touch a file.

## Dependencies by contract area

This repo has **zero SwiftPM dependencies** (`Package.swift` `dependencies` is empty) — every dependency is an Apple system framework, a macOS CLI tool, or one external HTTP API.

| Dependency | Area | Reference file | Last updated |
|---|---|---|---|
| SkyLight private framework (`SLSConfigureDisplayEnabled`) | Core mechanism — highest risk | [skylight-private-api.md](./mac-app-blackout/skylight-private-api.md) | 2026-09-22 |
| CoreGraphics display configuration & notifications | Core mechanism | [coregraphics-display-configuration.md](./mac-app-blackout/coregraphics-display-configuration.md) | 2026-09-22 |
| SwiftUI `MenuBarExtra` | App shell | [swiftui-menubarextra.md](./mac-app-blackout/swiftui-menubarextra.md) | 2026-09-22 |
| AppKit `NSWorkspace` / notification centres / `NSAlert` | Lifecycle & UI | [appkit-workspace-notifications.md](./mac-app-blackout/appkit-workspace-notifications.md) | 2026-09-22 |
| `ServiceManagement.SMAppService` | Launch at login | [servicemanagement-smappservice.md](./mac-app-blackout/servicemanagement-smappservice.md) | 2026-09-22 |
| `pmset` / `caffeinate` / `pgrep` CLI tools | Touch Bar recovery | [pmset-caffeinate-pgrep.md](./mac-app-blackout/pmset-caffeinate-pgrep.md) | 2026-09-22 |
| GitHub Releases REST API (`releases/latest`) | Update check | [github-releases-api.md](./mac-app-blackout/github-releases-api.md) | 2026-09-22 |
| swift-testing (`@Test`) + this repo's `test.sh` CLT quirk | Tests | [swift-testing-with-clt.md](./mac-app-blackout/swift-testing-with-clt.md) | 2026-09-22 |
