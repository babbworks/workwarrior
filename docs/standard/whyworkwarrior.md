# Why Workwarrior?

Most productivity tools force you into one paradigm. Task managers don't track time. Time trackers don't do accounting. Journals live in a separate app. Ledgers live in another. And none of them understand that you might have three completely different work contexts that should never touch each other.

The tools themselves are excellent. TaskWarrior is the best task manager ever built for the terminal. TimeWarrior tracks time with zero friction. JRNL turns journaling into a one-liner. Hledger brings double-entry accounting to plain text files. Each is best-in-class at what it does.

The problem is the space between them.

When you start a task, your time tracker doesn't know. When you finish a project, your ledger doesn't reflect it. When you switch from client work to personal tasks, every tool needs to be reconfigured. Your data is scattered across config files, databases, and directories with no awareness of each other.

Workwarrior is the layer that makes them work together.

## The Profile Model

A profile is a complete, isolated workspace. Your `work` profile has its own tasks, its own time tracking, its own journals, its own ledgers. Your `personal` profile has entirely separate copies of everything. Switching is instant — one command changes the environment for all five tools simultaneously.

This isn't a wrapper that hides the tools. You still use `task`, `timew`, `j`, and `l` directly. Workwarrior just makes sure they're all pointed at the right data for your current context. The tools don't even know Workwarrior exists.

## The Unified Command

Everything routes through `ww`. Twenty-plus service domains — profiles, journals, ledgers, groups, models, extensions, sync, search, export, questions, and more — all accessible from one command. But you're never forced through it. The shell functions (`task`, `timew`, `j`, `l`) work exactly as the underlying tools expect.

## The Browser UI

For people who want a visual layer, `ww browser` launches a locally-served web interface. No cloud. No accounts. No external dependencies. Just a Python 3 server on localhost with 15+ panels covering tasks, time, journals, ledgers, and every service in the system. A unified command input accepts natural language — "add a task to review the budget due friday" — and translates it into the right tool command.

## The Heuristic Engine

627 compiled regex rules match natural language input before any AI is involved. No network call, no latency, no LLM needed for routine operations. The rules cover all 19 command domains with 6 phrasing variations per command. When the heuristics can't match, an optional local LLM (ollama) handles the translation. The system gets smarter over time — every command is logged, and the compiler can digest past AI translations into new heuristic rules.

## Who It's For

Workwarrior is for people who live in the terminal, manage multiple work contexts, and want their productivity tools to work together without giving up control of any of them. It's for developers, consultants, freelancers, researchers — anyone who needs clean separation between projects and the ability to track tasks, time, notes, and money in one place.

It's not a replacement for any of the tools it wraps. It's the thing that was missing between them.
