# Sasih

Turn off your MacBook's built-in display without closing the lid. Keyboard, trackpad, Touch Bar, and speakers keep working exactly as before — only the internal panel goes dark.

Requires an external display to be connected (macOS won't allow the only display to be disabled).

## Why

Real clamshell mode requires closing the lid, which disables the built-in keyboard, trackpad, and Touch Bar — so you need an external keyboard/mouse just to use the machine. If you want a single-monitor-only workflow but still want to use the built-in keyboard, trackpad, and speakers, there's no first-party way to do that. Sasih is a small, free, single-purpose menu-bar app that does just this one thing.

## Safety nets

The one real risk with a feature like this is getting stuck with a black internal display and no way to see anything. Sasih is built to make that impossible:

- **Unplug your external display while the internal one is off** → the internal display turns back on automatically. You're never left with zero active displays.
- **App crashes or gets force-quit while the internal display is off** → restored automatically on next launch.
- **Quit normally** → internal display is restored before the app exits.
- **Mac sleeps and wakes** → your last chosen state (off/on) is restored automatically.

## Requirements

- Apple Silicon Mac
- macOS 13 (Ventura) or later
- An external display connected

## Install

Download the latest DMG from [Releases](https://github.com/malemalice/sasih/releases), open it, and drag Sasih into Applications. Since this isn't distributed through the App Store (see [Why the private API](#why-the-private-api) below), macOS Gatekeeper may ask you to confirm before first launch.

## How it works

The menu bar icon shows a moon: full when the internal display is on, dark when it's off. Click it to toggle. Enable "Launch at Login" from the same menu if you want it always available.

## Why the private API

Turning off just the internal panel while the lid is open isn't exposed through any public macOS API — it relies on `SLSConfigureDisplayEnabled` (with a fallback to the older `CGSConfigureDisplayEnabled`), a private CoreGraphics/SkyLight symbol. That means:

- Sasih can never ship on the Mac App Store — this is direct distribution by design, not a limitation to work around.
- Apple could change or remove this API in a future macOS release, which would break the app until updated. There's no public alternative; this is accepted as an ongoing maintenance risk, not a blocker.

See `TRD.md` for the full technical detail.

## Building from source

This machine builds with Command Line Tools only (no full Xcode.app install), so the build/test scripts pass a few extra search-path flags Xcode would normally provide.

```bash
./test.sh          # runs the SasihCore test suite
./build.sh          # builds Sasih.app (release) from the current source
./build.sh --debug  # debug build
./build.sh --sign   # codesign with $SASIH_SIGNING_IDENTITY (Developer ID Application)
./dmg.sh            # packages Sasih.app into Sasih.dmg (run build.sh first)
```

## License

MIT — see `LICENSE`.
