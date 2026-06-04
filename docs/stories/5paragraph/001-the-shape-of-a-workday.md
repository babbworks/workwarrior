# The Shape of a Workday

Marcus opens his terminal at 8:47 AM and types `p-work`. Two characters and a hyphen. Everything reconfigures around him: his task list is the sprint board, his time tracker is pointed at billable hours, his journal is the engineering log, his ledger tracks operating costs. He runs `ww next` and sees the three things that matter most today, scored and sorted by urgency, dependencies, and age. He picks the first one, runs `ww start 42`, and the clock starts. Not a mental note. Not a browser tab. An actual timer, in the terminal, connected to the task.

Three hours later he pauses for a meeting. `ww stop`. TimeWarrior logs the interval. He takes notes in the meeting and runs `ww log "resolved the ambiguity around the API contract"` — one line, timestamped, appended to the engineering journal for this profile. After the meeting he runs `ww start 42` again. The clock resumes. At the end of the day, `ww summary` tells him where the hours went — not in a dashboard that requires interpretation, but in plain text that reads like a ledger.

On Friday afternoon he invoices a client. He runs `ww ledger` and sees the week's tracked time already expressed in hours. He copies the numbers, generates an invoice, and records the transaction. Everything that needed to be true in order to bill accurately — the task, the time, the note, the amount — existed in the same profile, connected by the same context, never confused with the personal projects he worked on at night.

When he closes the laptop he types `p-personal`. The work profile doesn't disappear. It's still there, stored, intact, waiting. But it no longer answers to commands. Now his task list is the home renovation backlog. His journal is the one where he writes about his kids. His ledger is the household budget. He is, in the most literal sense that software can achieve, somewhere else.

This is the shape Workwarrior was designed to give a workday: clear edges. Not a single river of tasks and times and notes that you're always wading through, but separate pools — each clean, each complete, each silent when you're not in it.
