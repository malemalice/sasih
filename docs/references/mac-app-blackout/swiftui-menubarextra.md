# SwiftUI MenuBarExtra Reference

> Repo: mac-app-blackout
> Version: macOS 13+ (`MenuBarExtra` requires Ventura)
> Source: Apple SwiftUI docs
> Last updated: 2026-09-22

## Overview

`MenuBarExtra` is the whole app shell: a status-item-like scene with a custom window-style menu surface. There is no `WindowGroup`, no Dock icon (`LSUIElement`), and no settings scene.

## Key APIs used in this repo

```swift
@main
struct SasihApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: appDelegate.viewModel)
        } label: {
            MenuBarIcon(viewModel: appDelegate.viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
```

| API | Notes |
|---|---|
| `MenuBarExtra(content:label:)` | label is the status item view; content is the popover |
| `.menuBarExtraStyle(.window)` | Gives a regular SwiftUI view tree (with `Toggle`, `Divider`, `Button`) instead of a stock menu — required for switches |
| `Image(nsImage:)` + `.isTemplate = true` | Menu bar glyph must be a template image |
| `.accessibilityLabel(...)` | State-bearing glyph needs a label |

## Common patterns

- Keep the label view dumb: it only maps `viewModel.isInternalDisplayOff` to an asset name.
- All state lives in the `@ObservedObject` view model; the app delegate owns the real managers.
- Use `@NSApplicationDelegateAdaptor` to keep AppKit lifecycle (callbacks, timers, `applicationWillTerminate`) while the scene stays declarative.

## Gotchas

- The label image must be sized explicitly (`.size = NSSize(width: 18, height: 18)`) and set as a template, or macOS renders it at wrong scale / wrong colour.
- `.menuBarExtraStyle(.menu)` (the default) does not support toggles/steppers properly — do not switch styles.
- Views in the window-style menu are recreated on each open; don't put durable state in `@State` (the view model handles durability). `@State` is fine for the `LaunchAtLogin` mirror (re-read on open) and hover state.
- Don't add a `Settings` scene "just in case" — this app deliberately has no preferences window.

## Do not use

- `NSStatusItem` directly (the scene replaces it) unless a future feature needs popover control that `MenuBarExtra` cannot express.
- Emoji/SF Symbols for the status glyph — custom template PNGs are the shipped design (see `design-system/icons.md`).
