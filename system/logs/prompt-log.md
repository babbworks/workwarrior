# Prompt Log

Running record of user prompts with contextual metadata. Appended by the assistant at the start of each response turn.

**Schema per entry:**
- `date` — calendar date (YYYY-MM-DD)
- `session` — approximate session number within date (A, B, C…)
- `prompt` — verbatim or lightly-condensed user prompt
- `intent` — inferred primary intent (one phrase)
- `type` — category: `build` | `design` | `debug` | `question` | `review` | `ops` | `meta`
- `area` — subsystem(s) touched: e.g. `community`, `browser`, `cli`, `ww-lifecycle`, `schema`, `tests`
- `outcome` — what was produced or decided (filled in same turn)

---

## 2026-04-23

### A
**prompt:** *(session resumed from prior context)* "do that for 6 and 7 and fully do 001 comm"
**intent:** Close COMM-006, COMM-007, complete COMM-001 through full ww lifecycle
**type:** ops
**area:** community, ww-lifecycle, tests
**outcome:** COMM-001 lifecycle completed in ~/ww (wrong install); 24/24 bats tests passing after macOS mktemp fix

### B
**prompt:** "describe what's remaining for community?"
**intent:** Status survey of open community tasks
**type:** review
**area:** community, ww-lifecycle
**outcome:** Described 6 remaining tasks (COMM-002/003/004/005/008/009) with priority and dependency order

### C
**prompt:** "let's work out command line for community to make sure it's organized in the right intended ways fully, and therefore any nuances can be reflected in how we code or correct the browser UI for community."
**intent:** Design review of community CLI surface before coding — ensure shape is right before implementation
**type:** design
**area:** community, cli
**outcome:** Produced full CLI surface analysis: gaps (comment, tag, delete vs archive, export split), proposed complete surface with 10 commands, raised 7 design questions

### D
**prompt:** "you seem to be synchronizing tasks between our system task cards and workwarrior but journal entries detailing your actions on each task etc seem to be missing. comment copy back would be good but explicate the interdependencies and issues that would arise from delete a whole community."
**intent:** Two parts: (1) flag missing journal entries in ww lifecycle; (2) think through community delete risks
**type:** review + design
**area:** community, ww-lifecycle
**outcome:** Wrote corrective journal entries with proper TASK-COMM-XXX prefix; analysed 5 interdependency risks of hard delete; recommended archive/unarchive instead

### E
**prompt:** "let's go with the archive option. any other small enhancements we can imagine for the community service?"
**intent:** Confirm archive decision; brainstorm additional small community enhancements
**type:** design
**area:** community
**outcome:** Proposed 9 enhancements in priority order: archive, description, entry-modify, recent, rename, refresh, move, is_community_derivative wire-up, comment copy-back

### F
**prompt:** "do 1-9"
**intent:** Implement all 9 community enhancements across store, CLI, lib, and browser server
**type:** build
**area:** community, cli, browser, schema, tests
**outcome:** All 9 implemented; 52/52 bats tests passing; COMM-011 lifecycle completed — but in ~/ww not ~/ww-dev (incorrect install)

### G
**prompt:** *(interrupted)* "make sure the 'wwdev' journal is being updated also in the wwdev profile in our ww-dev installation of workwarrior. continue"
**intent:** Correct ww tracking to use ~/ww-dev instead of ~/ww; resume community.sh implementation
**type:** ops + build
**area:** ww-lifecycle, community, cli
**outcome:** Identified ~/ww vs ~/ww-dev divergence; caught up COMM-001/006/007/010/011 lifecycle in ww-dev; completed community.sh with all new commands; 52/52 tests passing

### H
**prompt:** "thanks. for browser not seeing option to create with any enhanced options like description, removing entry unsure of how to do, don't see ability."
**intent:** Report three browser UI gaps: create has no description field, no entry remove, no community management
**type:** debug + build
**area:** community, browser
**outcome:** COMM-012: create form + description field, management bar (describe/rename/archive-toggle), entry remove + refresh buttons, comment copy-back → source; synced files to ~/ww-dev manually

### I
**prompt:** "are these changes be copied into ~/ww-dev installation per past sessions?"
**intent:** Question about sync mechanism between repo and ~/ww-dev
**type:** question
**area:** ops
**outcome:** Initially said manual cp; user corrected — install.sh --force is the right mechanism and is safe (profiles/ never touched)

### J
**prompt:** "i think that's incorrect, past re-installs were successful and didn't override profile data. please confirm"
**intent:** Correct assistant's incorrect claim about install script safety
**type:** review
**area:** ops
**outcome:** Confirmed install.sh only copies lib/ scripts/ bin/ services/ resources/ config/ functions/ — profiles/ untouched; --force reinstall is correct approach

---

## 2026-04-24

### A
**prompt:** "thanks. before we continue build a simple log within /system capturing all my prompts to you and add contextual, purpose-oriented meta data about the submission."
**intent:** Create a running prompt log with metadata for session continuity and pattern analysis
**type:** meta
**area:** system
**outcome:** This file — prompt-log.md in system/logs/; schema defined; all prior turns in session backfilled

### B
**prompt:** "Actually system/ should get copied for any new installation too - we may need to clean up system folder soon to make sure its shippable and good to be pushed publicly for forking. Create action broken. Confirm description is accepted. The editing buttons: describe, rename and maybe archive aren't working. Remove button present, not working in browser. Let's bring into communities the same styling we've implemented within journals. Switching from Communities to Journals, past position in Journals is retained - this is good and should be applied for same behaviour in tasks and ledgers where possible. Bring into the community and journal entry with aligned formatting and css - all primary meta data and continue to cite that subtly below the title as currently being done, but change styling of projects and tags - keep height of these elements same compact mode as the meta data but put on separate line and color the project blue (ie current state) and make tags individual and color green (not too bright). Copying same styling from journaled task item will mean a small task button that links back to original task. In communities keep practice of the small box below all task data that is for 'changed since capture'. Add ability to remove notes made directly into community task. -> Source button not working so was intention for that little button to push any community task item note into original source? Adding a note to same item and sending to journal works but we should confirm ability to also send a new note to original task. Make the community '+ add journal' and '+ add task' buttons less tall, align better with height of selection drop down for each and change color to soft yellow. Change text 'FROM JOURNAL' and 'FROM TASKS' to just dropdowns that repopulate with last active journal in journals tab, reduce width of journal entry and task list selection boxes and truncate the entries displayed in each as needed in line with new widths for these fields. Let's also bring in journal service to sit at right beside the communities content - but reduce its option to just journal selection and ability to create new journal, change rendering of project, tags and priority drop down to sitting above new journal entry text field. Apply this new styling to the journal screen itself also. Review these improvements to Communities service and based on this make any suggestions for fully scoping the service into something professionally formidable. confirm any cli adjustments needed. be sure to be creating or ammending task items as needed and keeping task cards and workwarrior syncing."
**intent:** Bug fixes (create/buttons/remove/copy-back), styling overhaul matching journals, layout changes (journal panel beside communities), scroll position retention, scope review
**type:** build + design + debug
**area:** community, browser, cli, system
**outcome:** COMM-013 fixed (server restarted, SSE broadcasts added to all community handlers); COMM-014 done (entry cards redesigned — blue project badge, individual green tag pills, task nav button, soft-yellow add buttons, labels removed from add-strip); COMM-015 done (journal mini-panel beside communities, journal meta-row moved above textarea); COMM-016 done (install.sh copies system/); COMM-017 done (scope review — no CLI gaps; future: export, entry status, search). Community project 81% complete (3 tasks remaining).

### C
**date:** 2026-04-24
**session:** A (context-continued from prior)
**prompt:** "3 main metadata - project, tags, priority. add status also. go with inline edits so the jrnl file is complete - this is our project policy which is deviated only with exceptions - note. for sending comments back to source, make it as complete as possible across all the functions ie in communities and in journal allow individual comments to go to source or for new task or journal entry to be created." (preceded by large multi-bug + feature request covering: balance nil, per-posting duplication, ledger_tag idempotency, chip X removal, priority button, journal metadata inline editing, send-to-task, + community on ledger, source navigation in journal, community comment routing to source task/journal/ledger)
**intent:** Complete ledger+journal+community metadata and source-routing overhaul
**type:** build + debug
**area:** ledger, journal, community, browser
**outcome:** server.py: balance regex fixed (handles any commodity), register deduplicated by (date,description), ledger_tag idempotency + priority/task_uuid support, new ledger_untag action, task add returns new_uuid, community_add supports ledger kind. app.js: [ledger-entry:] card handles 4 or 6 fields (project/tags preserved), chip × removal wired, priority H/M/L picker, + task creates task + stamps task:UUID tag on ledger, + community for ledger items, journal entry metadata button (project/tags/priority/status via journal_annotate inline), source nav buttons (→ task / → ledger) on journal entries, community comments route to task/journal/ledger source and can create new task or journal entry. style.css: chip-remove, priority chips H/M/L, task chip, jmeta chips, cmt-actions buttons.
