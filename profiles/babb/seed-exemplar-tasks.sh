#!/usr/bin/env bash
# seed-exemplar-tasks.sh — Seed the babb profile with exemplar tasks.
# Run under the babb profile: p-babb && bash profiles/babb/seed-exemplar-tasks.sh
#
# Creates representative tasks that demonstrate the full ww feature set:
#   - plain task with tags and priority
#   - project task with time tracking
#   - GitHub-synced task linked to babbworks/workwarrior#1
#
# Safe to run multiple times — checks for existing tasks before creating.

set -euo pipefail

if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
    echo "Error: no profile active. Run: p-babb" >&2
    exit 1
fi

if [[ "${WORKWARRIOR_BASE}" != *"/babb" ]]; then
    echo "Error: babb profile must be active (current: ${WORKWARRIOR_BASE})" >&2
    exit 1
fi

echo "Seeding exemplar tasks for babb profile..."
echo ""

# ── Task 1: plain task ───────────────────────────────────────────────────────
if ! task description:"Review ww onboarding flow" 2>/dev/null | grep -q "Review ww"; then
    task add "Review ww onboarding flow" \
        priority:H \
        +ww +ux \
        project:workwarrior \
        due:2026-05-01
    echo "  ✓ Task 1: Review ww onboarding flow"
else
    echo "  ↷ Task 1 already exists, skipping"
fi

# ── Task 2: project task (demonstrates time tracking) ───────────────────────
if ! task description:"Write babb exemplar documentation" 2>/dev/null | grep -q "Write babb"; then
    task add "Write babb exemplar documentation" \
        priority:M \
        +ww +docs \
        project:workwarrior \
        desc:"Reference profile demonstrating full ww integration"
    echo "  ✓ Task 2: Write babb exemplar documentation"
else
    echo "  ↷ Task 2 already exists, skipping"
fi

# ── Task 3: GitHub-synced task (babbworks/workwarrior#1) ────────────────────
if ! task description:"Establish Master TASKDATA File" 2>/dev/null | grep -q "TASKDATA"; then
    task add "Establish Master TASKDATA File for Project" \
        priority:M \
        +ww +github \
        project:workwarrior \
        githubrepo:babbworks/workwarrior \
        githubnumber:1 \
        githuburl:"https://github.com/babbworks/workwarrior/issues/1" \
        githubstate:OPEN
    echo "  ✓ Task 3: GitHub issue #1 (babbworks/workwarrior)"
    echo "     Run 'github-sync enable <id> 1 babbworks/workwarrior' to activate two-way sync"
else
    echo "  ↷ Task 3 already exists, skipping"
fi

echo ""
echo "Done. View tasks: task project:workwarrior"
echo "Start time tracking: timew start <task-id>"
echo "Pull GitHub issues:  i pull"
