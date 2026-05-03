# Acknowledgements

## Original Author

This program is based on **t** (a command-line todo list manager) created by **Steve Losh**.

- **Original Project:** [t - A command-line todo list manager](https://github.com/sjl/t)
- **Original Author:** Steve Losh
- **License:** MIT License (see LICENSE file)
- **Copyright:** Copyright (c) 2009 Steve Losh

## Modifications for Workwarrior

This version has been adapted for integration with the Workwarrior project with the following changes:

### Changes Made

1. **Renamed from `t` to `list`**
   - Program renamed from `t.py` to `list.py`
   - Command changed from `t` to `list` for consistency with Workwarrior's naming conventions
   - Rebranded as a "Simple list manager" rather than "todo list manager"

2. **Folder Structure**
   - Relocated from standalone tool to `tools/list/` within Workwarrior
   - Integrated into Workwarrior's bundled tools ecosystem

3. **Integration**
   - Bundled as part of Workwarrior installation
   - Documented in Workwarrior's installation and service documentation
   - Positioned as a lightweight alternative to TaskWarrior for quick list management

### Purpose in Workwarrior

The `list` tool serves as a minimalist list manager for users who want to quickly capture items without the organizational overhead of TaskWarrior. It complements Workwarrior's suite of productivity tools:

- **TaskWarrior** - Full-featured task management (shortcut: `t`)
- **TimeWarrior** - Time tracking (shortcut: `a`)
- **JRNL** - Journaling (shortcut: `j`)
- **Hledger** - Financial tracking (shortcut: `l`)
- **list** - Simple list management (shortcut: `list`)

### Original Philosophy Preserved

We have maintained the original philosophy of the tool:

> "t is for people that want to *finish* tasks, not organize them."

The tool remains simple, fast, and focused on getting things done rather than organizing them.

## Attribution

We are grateful to Steve Losh for creating this excellent tool and releasing it under the MIT License, which allows us to adapt and integrate it into Workwarrior while preserving its simplicity and effectiveness.

## License

This modified version maintains the original MIT License. See the LICENSE file for full license text.
