# Open Questions

| # | Question | Status | Notes |
|---|---|---|---|
| 1 | Minimum macOS version to support | Effectively resolved | Mechanism confirmed working on Apple Silicon + macOS 13/Ventura and later — see `trd/mac-app-blackout/constraints-integrations.md`. `LSMinimumSystemVersion` is pinned to 13.0. |
| 2 | Whether to eventually add a software-blackout fallback mode for the no-external-display case | Open | Deliberately deferred; a materially different mechanism (overlay window). See `roadmap.md` item 4. |
| 3 | Touch Bar blank-panel root cause on 13" M1/M2 MacBook Pro | Open | Working mitigation shipped (`TouchBarRecovery`); WindowServer-level cause unconfirmed. Watch edge cases: wake-from-sleep / crash-recovery paths do not call the nudge. |
| 4 | Does the `Auto-Blackout` (auto-revert on reconnect) preference cover all user intents? | Open | Added after MVP; default is on. No user feedback yet. |
