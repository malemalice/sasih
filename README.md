# Sasih

Turn off your MacBook's built-in display without closing the lid. Keyboard, trackpad, Touch Bar, and speakers keep working exactly as before — only the internal panel goes dark.

Requires an external display to be connected (macOS won't allow the only display to be disabled).

**[⬇ Download the latest version](https://github.com/malemalice/sasih/releases/latest)**

## Why you'd want this

Real clamshell mode (closing the lid) disables your built-in keyboard, trackpad, and Touch Bar, forcing you to use an external keyboard and mouse. If you just want a clean single-monitor setup while keeping your MacBook's own keyboard, trackpad, and speakers, macOS has no first-party way to do that. Sasih is a small, free, single-purpose menu-bar app that does exactly this one thing — nothing more.

### How this compares to "just dim the brightness to 0"

A common manual workaround is to drag the internal display to the side in System Settings and pull its brightness slider down to zero. That's free and works in a pinch, but it only turns off the backlight — the internal panel is still a fully active display as far as macOS is concerned. Sasih instead disables the display itself, the same way clamshell mode does.

| | Dim brightness to 0 | Sasih |
|---|---|---|
| Screen appears black | Yes | Yes |
| Internal panel still counted as an active display | Yes | No — fully disabled |
| Windows/dialogs can silently open on the dark screen and "go missing" | Yes | No |
| Menu bar / Spaces / Mission Control span both screens | Yes | No — consolidates onto the external display |
| One-click toggle | No (multiple manual steps) | Yes |
| Auto-restores if you unplug the external display | No | Yes |

## Features

- **One-click toggle** — turn the internal display on or off from the menu bar.
- **Everything else keeps working** — keyboard, trackpad, Touch Bar, and speakers are unaffected.
- **Launch at Login** — optionally have Sasih start automatically when you log in.
- **Built-in safety nets** (see below) — you can't get stuck staring at a black screen.
- **Free and lightweight** — no account, no tracking, no background bloat.

## Safety nets

The one real risk with a feature like this is getting stuck with a black internal display and no way to see anything. Sasih is built to make that impossible:

- **Unplug your external display while the internal one is off** → the internal display turns back on automatically. You're never left with zero active displays.
- **App crashes or gets force-quit while the internal display is off** → restored automatically on next launch.
- **Quit normally** → internal display is restored before the app exits.
- **Mac sleeps and wakes** → your last chosen state (off/on) is restored automatically.

## Requirements

- Apple Silicon Mac (M1 or newer)
- macOS 13 (Ventura) or later
- An external display connected

## Install (2 minutes, no technical steps)

1. Go to the [Releases page](https://github.com/malemalice/sasih/releases/latest) and download the `.dmg` file under **Assets**.
2. Open the downloaded `.dmg` file — it opens a small window with the Sasih icon.
3. Drag **Sasih** into the **Applications** folder shown in that window.
4. Open **Applications** and double-click **Sasih** to launch it.
5. Since Sasih isn't distributed through the Mac App Store, macOS Gatekeeper may show a warning the first time you open it. If that happens:
   - Right-click (or Control-click) the Sasih icon in Applications and choose **Open**, then confirm **Open** in the dialog that appears. You only need to do this once.

That's it — you'll see a moon icon appear in your menu bar at the top of the screen.

## How to use it

Look for the moon icon in your menu bar (top-right area of the screen, near the clock/battery icons):

- **Full moon** 🌕 = internal display is **on**.
- **Dark moon** 🌑 = internal display is **off**.

Click the icon and choose the toggle to switch between on and off. If you want Sasih to start automatically every time you log in, turn on **Launch at Login** from the same menu.

Remember: your external display must stay connected while the internal display is off — Sasih automatically turns the internal display back on if you unplug it, so you're never left without a visible screen.

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
