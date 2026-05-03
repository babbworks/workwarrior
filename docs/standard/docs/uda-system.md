---
layout: doc
title: UDA System
eyebrow: Documentation
description: TaskWarrior User Defined Attributes — management, sync permissions, urgency tuning, browser UI rendering.
permalink: /docs/uda-system
doc_section: reference
doc_order: 3
---

TaskWarrior's User Defined Attributes let you add arbitrary typed fields to every task. Workwarrior treats UDAs as a first-class concept with a full management surface, source classification, sync permission system, and automatic browser UI rendering.

## UDA Types

| Type | Declaration | Use |
|------|------------|-----|
| string | `uda.client.type=string` | Text values — client name, phase, component |
| numeric | `uda.billable.type=numeric` | Numbers — hours, story points, rates |
| date | `uda.deadline.type=date` | Dates — hard deadlines, review dates |
| duration | `uda.estimate.type=duration` | Time estimates |

## Source Badges

The UDA registry classifies every UDA by source:

| Badge | Source |
|-------|--------|
| `[github]` | Injected by Bugwarrior from issue tracking services |
| `[extension:<name>]` | Added by TaskWarrior extensions (TWDensity, taskcheck) |
| `[custom]` | Defined by you via `ww profile uda add` |

Extension-classified UDAs are protected from accidental deletion.

## Management

```bash
ww profile uda list                    # All UDAs with source badges
ww profile uda add client              # Interactive creation wizard
ww profile uda remove billable         # Remove (blocked for extension UDAs)
ww profile uda group work              # Apply UDA template group
ww profile uda perm client nosync      # Set sync permission
ww profile uda perm notes private      # Exclude from AI context
```

## Sync Permissions

| Token | Effect |
|-------|--------|
| `nosync` | Excluded from github-sync push |
| `private` | Excluded from AI context |
| `noai` | Excluded from AI context |
| `readonly` | Pull-only, never pushed to GitHub |

Use `nosync` for internal priority or classification fields that shouldn't appear as GitHub labels.

## Urgency Tuning

UDAs can contribute to TaskWarrior's urgency score:

```bash
ww profile urgency    # Interactive tuner
```

Add a numeric UDA called `billable` and tune its urgency coefficient so client billable tasks float up in priority. Different profiles can have completely different urgency models.

## Browser UI Rendering

The browser task editor renders all UDAs defined in the active profile automatically — no configuration. A profile with `client`, `estimate`, `sprint`, and `billable` UDAs gets a task editor with all four fields, correctly typed.

## UDA Template Groups

```bash
ww profile uda group project    # Apply project management UDA set
ww profile uda group finance    # Apply financial tracking UDA set
```

Template groups apply pre-defined sets of UDAs documented in `docs/setups/`. These are starting points — add, remove, and tune as needed.

Common template UDAs: `client`, `estimate`, `billable`, `rate`, `sprint`, `epic`, `component`, `phase`, `owner`, `reviewer`.
