# services/profile/urgency.sh

**Type:** Executed service script  
**Invoked by:** `ww profile urgency <subcommand>`

---

## Role

Interactive surface for TaskWarrior's urgency coefficient system. Allows viewing, setting, tuning, and explaining urgency scores without needing to know raw `.taskrc` syntax. Writes to a `# === WW URGENCY ===` sentinel block in the active profile's `.taskrc`.

---

## How TaskWarrior Urgency Works

Urgency is a weighted sum: `urgency = Σ (coefficient × factor_value)`

Key coefficient types:
- `urgency.due.coefficient` — due date proximity (default: 12.0)
- `urgency.blocking.coefficient` — task is blocking others (default: 8.0)
- `urgency.uda.<name>.coefficient` — presence of any value in a UDA
- `urgency.uda.<name>.<value>.coefficient` — specific UDA value match

---

## Subcommands

**`show`**  
Displays all current coefficients grouped by: built-in factors → UDA presence → UDA values. Also shows effective urgency score for each pending task alongside the breakdown of contributing factors.

**`set <factor> <value>`**  
Sets `urgency.<factor>.coefficient=<value>` in `.taskrc`. Validates that value is numeric. Examples:
```bash
ww profile urgency set uda.phase.review 5.0
ww profile urgency set due 10.0
```

**`tune`**  
Interactive wizard. Steps through each UDA group and current coefficient. Prompts to raise/lower/leave each one. Shows before/after urgency ranking for top 10 tasks before confirming writes.

**`reset`**  
Removes all ww-managed urgency coefficients from `.taskrc` (the entire `# === WW URGENCY ===` block). Restores TaskWarrior defaults.

**`explain <task-id>`**  
Shows full urgency breakdown for a specific task:
```
due date:     +8.4  (due in 3 days)
phase=review: +5.0
goals set:    +2.0
blocked:      -5.0
─────────────────
total:        10.4
```

---

## Group-Level Urgency

`ww group urgency set <group> <factor> <value>` writes the coefficient into each member profile's `.taskrc`. Shared urgency rules propagate across group members.

---

## Relationship to TWDensity

`ww profile density install` writes `urgency.uda.density.0..30.coefficient` entries to `.taskrc`. These appear in `ww profile urgency show` and can be tuned via `ww profile urgency tune`. The two surfaces are complementary — density install writes initial coefficients, urgency tune adjusts them.

## Changelog

- 2026-04-10 — Initial version
