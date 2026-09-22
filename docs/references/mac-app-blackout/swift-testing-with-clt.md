# swift-testing with Command Line Tools Reference

> Repo: mac-app-blackout
> Version: Swift 6.0 toolchain (CLT only — no Xcode.app on this machine)
> Source: Swift Package Manager / swift-testing docs + the repo's `test.sh`
> Last updated: 2026-09-22

## Overview

Tests use **swift-testing** (`import Testing`, `@Test func ...`, `#expect(...)`) — not XCTest — and must run on a machine that has only Command Line Tools installed.

## Key invocation used in this repo

```bash
./test.sh                      # wrapper — always use this
swift test \
  -Xswiftc    -F -Xswiftc    "$CLT_FRAMEWORKS" \
  -Xlinker    -F -Xlinker    "$CLT_FRAMEWORKS" \
  -Xlinker -rpath -Xlinker   "$CLT_FRAMEWORKS"

# CLT_FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

Without those flags, `swift test` fails to find the swift-testing runtime framework on a CLT-only machine.

## Common patterns

- Test targets: `SasihCoreTests`, `SasihAppTests` (declared in `Package.swift`, each with explicit `path:`).
- Fakes via the injected protocols: `FakeConfigurer`/`FakeInfoProvider`/`FakeIDStore` (see `Tests/SasihCoreTests/DisplayManagerTests.swift`), `FakeRunner`/`FakeClock`-style injections for `TouchBarRecovery`.
- Group tests in a `struct <Subject>Tests { @Test func ... }`; use descriptive names stating the invariant.

## Gotchas

- `swift test` from anywhere else in the repo works only because `Package.swift` pins explicit `path:` values — don't move test files without updating the manifest.
- Don't add `import XCTest` — mixing frameworks in one target causes symbol/runtime confusion with swift-testing; keep everything `Testing`.
- Any new test that touches UserDefaults must inject an isolated suite (`UserDefaults(suiteName:)`) and any new file path a temp URL — never the real `.standard`/home-file (see `DisplayIDStoreTests`).
- Hardware-dependent behaviour cannot run here — that's the manual matrix's job (`playbooks/hardware-verification.md`), not `./test.sh`.

## Do not use

- `xcodebuild test` (no Xcode.app on the target dev machine).
- Adding SPM dependencies to fix tooling issues — the zero-dependency constraint is deliberate.
