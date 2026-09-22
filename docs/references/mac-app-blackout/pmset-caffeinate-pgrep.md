# `pmset` / `caffeinate` / `pgrep` Reference

> Repo: mac-app-blackout
> Version: macOS 13+ bundled CLI tools (`/usr/bin/`)
> Source: `man pmset`, `man caffeinate`, `man pgrep`
> Last updated: 2026-09-22

## Overview

`TouchBarRecovery` shells out to reproduce the manually-confirmed fix for the blank-Touch-Bar quirk: a display sleep → immediate wake cycle. It also uses `pgrep` to detect Touch Bar hardware.

## Key invocations used in this repo

| Command | Purpose | Parsed? |
|---|---|---|
| `/usr/bin/pgrep -x TouchBarServer` | Detect Touch Bar hardware (exit 0 = present) | Exit status only |
| `/usr/bin/pmset displaysleepnow` | Put displays to sleep (the fix's first half) | Exit status ignored |
| `/usr/bin/caffeinate -u -t 1` | Force an immediate user-active wake for 1 second (the fix's second half) | Exit status ignored |

Sequence: `pgrep` → (if present) background queue → `pmset displaysleepnow` → sleep 0.5s → `caffeinate -u -t 1`.

## Common patterns

- Abstract process execution behind `ProcessRunning` (protocol in `TouchBarRecovery.swift`) so tests inject a fake runner — never call `Process` directly from logic.
- AbsolUTE paths (`/usr/bin/...`) — do not rely on `PATH` resolution.
- `standardOutput`/`standardError` are set to `FileHandle.nullDevice`.
- All of this runs on a background queue (`.utility`), never the main thread, and only on the manual toggle off→on path.

## Gotchas

- `TouchBarServer` exists only on Touch Bar Macs (13" M1/M2 MacBook Pro); on all other Apple Silicon Macs `pgrep` exits non-zero and the nudge is a no-op. Keep it that way — do not add other heuristic "hardware" checks.
- **Do not run this nudge on the sleep/wake path.** It synthesizes a display sleep/wake cycle, which feeds the app's own reconfiguration callbacks and can race wake handling (this was tried on 2026-08-23 and reverted on 2026-08-26 — see `decisions.md`).
- The 0.5s delay is required: waking before the display actually sleeps doesn't restart the DFR session.
- These tools may prompt nothing and fail silently under a sandbox — the app is deliberately unsandboxed (see TRD constraints).

## Do not use

- `killall ControlStrip` / `killall TouchBarServer` as a fix — proven ineffective for this symptom (only logout/login or a display sleep/wake cycle works).
- Shelling out for anything on a hot path; this only runs once per manual re-enable.
