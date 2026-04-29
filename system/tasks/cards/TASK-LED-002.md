## TASK-LED-002: Agent/session ledger account hierarchy + session recording process

Goal:                 Define and document the canonical account hierarchy for non-accounting
                      hledger use within workwarrior: time tracking, agent sessions, project
                      costs, and output measurement. Codify the routine for recording session
                      data (journal + ledger + timew) at session end.

Background:           hledger is used in ww primarily for project and session ledgering, not
                      traditional accounting. The double-entry model is preserved but the
                      commodity is time (h), sessions (sess), or cost ($) rather than money.
                      The account hierarchy should mirror the accounting principle of
                      assets/expenses/income/liabilities but adapted for this use.

Proposed hierarchy:

    ; ── Time invested (like "expenses") ─────────
    time:project:<name>        ; hours on a project
    time:admin                 ; overhead/admin time
    time:review                ; code review, reading
    time:ops                   ; ops/devops work

    ; ── Sessions (sources of work, like "income") ─
    sessions:agent:claude      ; claude-assisted sessions
    sessions:manual            ; unassisted sessions

    ; ── Costs (external spend) ───────────────────
    costs:api:anthropic        ; API usage
    costs:tools                ; tool subscriptions
    costs:hosting              ; compute/hosting

    ; ── Output (value produced, like "assets") ───
    output:features            ; shipped features
    output:docs                ; documentation
    output:tests               ; test coverage

    ; ── Backlog (deferred work, like "liabilities") ─
    backlog:tech-debt          ; known tech debt
    backlog:bugs               ; tracked bugs

Example session transaction:
    2026-04-24 * ww ledger UI improvements
        ; claude-session: ledger-ui-overhaul
        time:project:ww-browser    2h
        sessions:agent:claude     -2h

Acceptance criteria:  1. Hierarchy documented in system/docs/ledger-account-hierarchy.md
                         with examples for time, cost, and output tracking.
                      2. Session recording process codified: what gets written to journal
                         (narrative), ledger (time+cost entry), and timew (interval tag).
                      3. A ww shortcut or alias for end-of-session recording is proposed
                         (may be a separate task to implement).
                      4. hledger cleared (*) / pending (!) / unmarked usage documented:
                         - unmarked = in-progress or unreviewed
                         - pending (!) = ready for review
                         - cleared (*) = reviewed/approved

Write scope:          system/docs/ledger-account-hierarchy.md  (new)
                      system/logs/decisions.md

Tests required:       none (documentation task)

Status:               open
Priority:             medium
