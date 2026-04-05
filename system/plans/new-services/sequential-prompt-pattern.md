# Sequential Prompt Pattern

A shared UX pattern for any service that creates structured, multi-section documents.
Defined here once; referenced by Plans, Decisions, and any future structured-section service.

---

## Editor Escape Hatch

Any command using this pattern accepts `--editor` (short: `-e`) to skip prompts entirely
and open the document directly in `$EDITOR`. The file is pre-populated with the template
structure (and inherited text if a prior version exists) before the editor opens.

```
ww plans add <name> --editor      — open pre-populated file in $EDITOR, skip prompts
ww plans edit <name> --editor     — open existing file in $EDITOR directly
```

This applies to all services using the sequential prompt pattern.

---

## Behaviour

When a user creates or edits a structured document, each section is presented one at a time
as an interactive prompt — not opened in `$EDITOR` as a blank file (unless `--editor` given).

```
Goal:
[previous text shown here, or empty on first use]
> _
```

- Previous text for this field is displayed above the input cursor
- Pressing Enter with no input accepts the previous text unchanged
- Typing anything replaces the previous text for this field
- Multi-line fields: blank line submitted with `.` on its own line (same as many CLI tools)
- After all prompts complete, the document is assembled and written (or printed if `--print`)

## Inheritance Rule

When creating a new version of a named document (same name, new date or v2+), the most
recent prior version's text is offered as the default for every field. The user steps
through only the fields they want to change — everything else inherits automatically.

## Scope of Application

Any service whose `add` command produces a structured multi-section document should use
this pattern. Currently:

| Service | Sections |
|---|---|
| Plans | Goal, Approach, Steps, Tags |
| Decisions | Context, Options Considered, Decision, Outcome, Tags |

Future structured services should adopt this pattern unless their creation flow is
inherently freeform (in which case `$EDITOR` is appropriate).

## Tier 2 — User-Defined Templates

Template creation follows the same sequential prompt flow, applied to template definition:

```
ww plans template add <type>
Section name: _
Prompt text for this section: _
Add another section? [y/N] _
```

This is identical in spirit to how the questions service solicits question definitions.
Templates stored as YAML:

```yaml
name: sprint-plan
sections:
  - heading: Goal
    prompt: What is this sprint trying to achieve?
  - heading: Scope
    prompt: What is in and out of scope?
  - heading: Risks
    prompt: What could go wrong?
```

## Implementation Notes (Tier 1)

- `read -r -p "$(label): " -e -i "$(previous_value)"` — readline pre-population
- Multi-line: accumulate lines until `.` sentinel, trim trailing sentinel
- Assembled document written via `printf` to target path
- No external dependencies beyond bash readline (`read -e -i`)
