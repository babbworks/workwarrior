# Behavioral Divergences from Upstream Tools

This document logs any places where workwarrior's browser UI or wrapper
layer behaves differently from the upstream tool's default behavior.

**No source code modifications have been made to TaskWarrior or TimeWarrior.**

All interactions use their standard CLI interfaces (`task`, `timew`).

---

## TimeWarrior: timew_start tag merging (REVERTED)

Added: session browser-ui, April 2026
Status: REVERTED — restored to standard timew behavior

The browser server's `timew_start` action briefly merged tags with any
active interval to simulate concurrent tracking. This was reverted because
timew is single-track by design. The standard behavior (new `timew start`
replaces the active interval) is now restored.

## TimeWarrior: description via journal

The Times form separates structured tags (sent to `timew start <tags>`)
from free-text descriptions (logged to the profile journal with a
`[time:<tags>]` prefix). TimeWarrior itself has no description field —
this is a ww UI convention, not a timew modification.

## TaskWarrior: UDA display grouping

The browser task editor groups UDAs into "user UDAs" (editable) and
"service UDAs" (read-only, collapsed). This is a UI presentation choice.
TaskWarrior itself treats all UDAs identically.
