## TASK-EXT-CAL-001: Calendar and reminders integration — design decision required

Goal:                 Integrate calendar and/or reminders into ww profiles. Scope is
                      deliberately open — this card captures the design decision space
                      before committing to an approach.

Background:           Three candidate approaches exist in the scanned extension list:

                      A. Aerex/icaltask — bidirectional TaskWarrior ↔ iCalendar VTODO sync
                         https://github.com/Aerex/icaltask · Python · 7★ · 2022
                         Syncs tasks to/from CalDAV servers (Nextcloud, Baikal, etc.)
                         Installs hooks via `icaltask install` → writes to active .taskrc
                         Profile-isolated: reads TASKRC. Last push 2022 — maintenance risk.

                      B. allgreed/tw-ical-feed — read-only iCal feed of tasks
                         https://github.com/allgreed/tw-ical-feed · Python · 2★ · 2024
                         Generates a .ics feed from TaskWarrior tasks for calendar apps
                         to subscribe to. One-way: tasks → calendar. Simpler, lower risk.

                      C. Build native ww reminders service
                         ww reminder add <task-id> <when>  → writes to profiles/<n>/reminders/
                         ww reminder list
                         ww reminder run  → checks due reminders, fires via osascript/notify-send
                         No external dependency. Profile-isolated by design.
                         Could integrate with macOS Reminders or just terminal notifications.

Design questions for operator:

1. DIRECTION
   Do you want tasks → calendar (one-way export/feed) or
   calendar → tasks (import meetings/events as tasks) or
   bidirectional?

2. CALENDAR TARGET
   macOS Calendar / Reminders, Nextcloud CalDAV, Google Calendar, or
   just a .ics file that any calendar app can subscribe to?

3. REMINDERS VS CALENDAR
   Are these the same feature (tasks with due dates appear in calendar)
   or separate (reminders = notifications, calendar = scheduling view)?

4. BUILD VS ADOPT
   Given icaltask's 2022 last push, is it worth adopting or should ww
   build a lightweight native reminders service?

5. SCOPE
   Should this be per-profile (work calendar ≠ personal calendar) or
   global (one calendar feed for all profiles)?

Acceptance criteria:  Deferred — pending design decision answers above.

Write scope:          TBD after design decisions.

Status:               parked — requires operator design decisions before implementation
Taskwarrior:          wwdev task 18 (29889f3b-8d52-4c10-a1e4-476bd220e93a) status:pending +waiting
