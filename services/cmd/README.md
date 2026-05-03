# CMD Service

Unified command interface for the browser UI. Accepts commands that span
tasks, times, journals, and ledgers — routed through the `ww` CLI.

## Log

All submitted commands are logged to `cmd.log` in JSONL format (one JSON
object per line). Each entry records:

- `command` — the command string as submitted
- `output` — first 500 chars of the result
- `ok` — boolean success
- `ts` — ISO timestamp
- `profile` — active profile at time of execution

The log file lives at `$WW_BASE/services/cmd/cmd.log` and is created on
first use. The browser UI reads it via `GET /data/cmd-log` and displays
the most recent 100 entries.

## Browser UI

The CMD tab in the sidebar provides:
- A single input for any `ww` subcommand
- Output display
- Scrollable history log with click-to-expand results

## Future

This service is the foundation for AI-assisted unified commands that can
orchestrate actions across all four functions (tasks, times, journals,
ledgers) from a single natural language instruction.
