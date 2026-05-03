# Ledger Account Hierarchy — Workwarrior

Workwarrior uses hledger for non-traditional double-entry accounting: the primary
commodities are time (h), sessions (sess), and cost ($), not money. The account
hierarchy mirrors standard accounting principles but is adapted for project and
session ledgering.

## Canonical Account Hierarchy

```hledger
; ── Time invested (analogous to "expenses") ──────────────────────────────────
time:project:<name>         ; hours on a specific project
time:admin                  ; overhead / coordination time
time:review                 ; code review, reading, research
time:ops                    ; devops, infrastructure, tooling
time:learning               ; study, exploration, prototyping

; ── Sessions (sources of work, analogous to "income") ────────────────────────
sessions:agent:claude       ; claude-assisted work sessions
sessions:agent:other        ; other AI-assisted sessions
sessions:manual             ; unassisted human sessions

; ── Costs (external spend, analogous to "expenses" in money) ─────────────────
costs:api:anthropic         ; Anthropic API usage
costs:api:openai            ; OpenAI API usage
costs:tools                 ; tool/SaaS subscriptions
costs:hosting               ; compute, VPS, cloud

; ── Output (value produced, analogous to "assets") ───────────────────────────
output:features             ; shipped product features
output:docs                 ; documentation written
output:tests                ; test coverage added
output:fixes                ; bugs resolved

; ── Backlog (deferred work, analogous to "liabilities") ──────────────────────
backlog:tech-debt           ; known technical debt
backlog:bugs                ; tracked defects
backlog:design              ; deferred design decisions
```

## Cleared / Pending / Unmarked Usage

hledger supports three transaction states:

| Marker | Symbol | Meaning in ww |
|--------|--------|---------------|
| Unmarked | (none) | In-progress or unreviewed — session just logged |
| Pending | `!` | Ready for review — session complete, awaiting sign-off |
| Cleared | `*` | Reviewed and approved — accurate record |

```hledger
; Unmarked — in progress
2026-04-27 ww ledger UI improvements
    time:project:ww-browser    2h
    sessions:agent:claude     -2h

; Pending — complete, needs review
2026-04-27 ! ww ledger UI improvements
    time:project:ww-browser    2h
    sessions:agent:claude     -2h

; Cleared — reviewed and accurate
2026-04-27 * ww ledger UI improvements
    time:project:ww-browser    2h
    sessions:agent:claude     -2h
```

## Session Recording Process

At the end of each work session, record in three places:

### 1. Journal (narrative)

```
[2026-04-27 17:30] Session: ww ledger improvements
Implemented 3-line ledger row redesign. Refactored renderLedger() to use
click-to-expand pattern matching journal entries. 2.5h total.
@project:ww @tags:browser,ledger @priority:M
```

### 2. Ledger (time + cost entry)

```hledger
2026-04-27 ww ledger row redesign
    ; claude-session: 0772f1ef
    ; output: ledger-row-redesign
    time:project:ww-browser    2.5h
    sessions:agent:claude     -2.5h
```

For sessions with API cost:
```hledger
2026-04-27 * API session — ww browser improvements
    time:project:ww-browser    3h
    sessions:agent:claude     -3h
    costs:api:anthropic        $0.85
    sessions:agent:claude      $-0.85
```

### 3. TimeWarrior (interval tag)

```
timew start ww-browser ledger-redesign
timew stop
```

## Shortcut: Session End Recording

A future `ww session end` command will automate steps 1-3 above. Until then,
run each step manually or use the browser's journal add + ledger add forms.

## Reports

Useful hledger queries for this hierarchy:

```bash
# Total time by project
hledger bal time:project --depth 2

# Cost summary
hledger bal costs

# Session breakdown
hledger bal sessions

# This week's time
hledger bal time --begin thisweek

# Full register for a project
hledger reg time:project:ww-browser
```
