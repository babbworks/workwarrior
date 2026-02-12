# Custom Services

This directory contains user-defined and specialized services that don't fit into other categories.

## Available Services

### configure-journals.sh

**Purpose:** Interactive guide for configuring JRNL settings for the active profile.

**Usage:**
```bash
# Method 1: Using the j shortcut (requires active profile)
p-work              # Activate profile first
j custom            # Open journals configuration

# Method 2: Using the custom command
custom journals     # Open journals configuration

# Method 3: Using the ww command
ww custom journals  # Open journals configuration
```

**Features:**
- **Journal Management:** Add new journals to your profile
- **Editor Configuration:** Choose external editor (nano, vim, VS Code, etc.)
- **Color Customization:** Set colors for body, date, tags, and title
- **Tag Symbols:** Configure which characters denote tags (@, #, etc.)
- **Default Time:** Set default hour and minute for entries
- **Display Settings:** Configure highlighting, line wrap, and indent character

**Important Notes:**
- Requires an active profile (use `p-<profile-name>` first)
- Creates backups of jrnl.yaml before modifications
- Validates all inputs before applying changes
- Shows information about planned `ww journal` commands

**Configuration Sections:**

1. **Manage Journals**
   - Add new journals to profile
   - List existing journals
   - Creates journal files automatically
   - Updates jrnl.yaml configuration

2. **External Editor**
   - Choose from common editors
   - Enter custom editor command
   - Handles editor-specific flags (--wait, -w)

3. **Colors**
   - Customize colors for body, date, tags, title
   - Available colors: BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, NONE

4. **Tag Symbols**
   - Set characters that denote tags
   - Common options: @, #, @#, +
   - Warns about shell quoting requirements for #

5. **Default Time**
   - Set default hour (0-23)
   - Set default minute (0-59)
   - Used when creating entries without specific time

6. **Display Settings**
   - Enable/disable tag highlighting
   - Set line wrap width
   - Configure indent character

**Example Session:**
```bash
$ p-work
✓ Activated profile: work

$ j custom
# or: custom journals
# or: ww custom journals

============================================================
         JRNL Configuration Guide
============================================================

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Managing Journals
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

There are two ways to manage journals in your profile:

1. Command-line (Recommended):
   ww journal add <journal-name>     # Add new journal
   ww journal list                   # List all journals
   ww journal remove <journal-name>  # Remove journal

   Note: These commands are planned but not yet implemented.
   See OUTSTANDING.md for status.

2. This configuration tool:
   • Guided prompts for adding/editing journals
   • Validates paths and settings
   • Updates jrnl.yaml automatically

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Press Enter to continue with configuration...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration Menu - Profile: work
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Manage journals (add/list)
  2. Configure external editor
  3. Configure colors
  4. Configure tag symbols
  5. Configure default time
  6. Configure display settings
  7. View current configuration
  8. Exit

Choose option [1-8]:
```

**Related Documentation:**
- See `OUTSTANDING.md` for planned `ww journal` commands
- See `.kiro/specs/workwarrior-profiles-and-services/requirements.md` for journal requirements
- See JRNL documentation: https://jrnl.sh/

---

## Adding Custom Services

To add your own custom service:

1. Create a new script in this directory:
   ```bash
   touch services/custom/my-service.sh
   chmod +x services/custom/my-service.sh
   ```

2. Add the service header:
   ```bash
   #!/usr/bin/env bash
   # Service: my-service
   # Category: custom
   # Description: Brief description of what this service does
   
   set -e
   
   # Source shared utilities
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../../lib/core-utils.sh"
   ```

3. Implement your service logic

4. Test your service:
   ```bash
   ./services/custom/my-service.sh
   ```

See `services/README.md` for detailed service development guidelines.

---

### configure-ledgers.sh

**Purpose:** Interactive guide for configuring Hledger settings for the active profile.

**Usage:**
```bash
# Method 1: Using the l shortcut (requires active profile)
p-work              # Activate profile first
l custom            # Open ledgers configuration

# Method 2: Using the custom command
custom ledgers      # Open ledgers configuration

# Method 3: Using the ww command
ww custom ledgers   # Open ledgers configuration
```

**Features:**
- **Ledger Management:** Add, remove, and set default ledgers
- **Initialization:** Create starter accounts and an opening balance entry
- **Data Entry:** Run `hledger add` for interactive transactions
- **Validation:** Run `hledger check` on the default ledger
- **Quick Reports:** balance, register, balancesheet, incomestatement

**Important Notes:**
- Requires an active profile (use `p-<profile-name>` first)
- Creates backups of `ledgers.yaml` before modifications
- Validates ledger names and paths
- Uses the profile’s `ledgers.yaml` as the source of truth

**Configuration Sections:**

1. **Manage Ledgers**
   - Add new ledger and file
   - Set default ledger
   - Remove ledger mapping

2. **Initialize Default Ledger**
   - Adds account declarations
   - Adds an opening balance entry

3. **Data Entry**
   - Runs `hledger add` on default ledger

4. **Validation**
   - Runs `hledger check` on default ledger

5. **Quick Reports**
   - balance, register, balancesheet, incomestatement

**Example Session:**
```bash
$ p-work
✓ Activated profile: work

$ l custom
# or: custom ledgers
# or: ww custom ledgers

============================================================
         Hledger Configuration Guide
============================================================

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration Menu - Profile: work
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Manage ledgers (add/set/remove)
  2. Initialize default ledger
  3. Add transaction (hledger add)
  4. Validate ledger (hledger check)
  5. Quick reports
  6. View ledgers.yaml
  7. Exit
```


---

### configure-tasks.sh

**Purpose:** Interactive guide for configuring TaskWarrior settings for the active profile.

**Usage:**
```bash
# Method 1: Using the custom command (recommended)
p-work              # Activate profile first
custom tasks        # Open TaskWarrior configuration

# Method 2: Using the ww command
ww custom tasks     # Open TaskWarrior configuration
```

**Note:** Unlike journals configuration, TaskWarrior configuration cannot be accessed via `t custom` because `t` is an alias directly to the `task` command. Use `custom tasks` or `ww custom tasks` instead.

**Features:**
- **Basic Settings:** Configure editor and confirmation prompts
- **Display Settings:** Customize verbose output and date format
- **Color Theme:** Choose from 10+ built-in themes
- **Urgency Coefficients:** Adjust task priority calculations
- **User Defined Attributes (UDAs):** Add, list, and remove custom task attributes
- **Report Configuration:** Information about customizing task reports

**Important Notes:**
- Requires an active profile (use `p-<profile-name>` first)
- Creates backups of .taskrc before modifications
- Validates all inputs before applying changes
- Supports extensive UDA management

**Configuration Sections:**

1. **Basic Settings**
   - Choose external editor (nano, vim, VS Code, Sublime, emacs, or custom)
   - Enable/disable confirmation prompts for destructive operations

2. **Display Settings**
   - Configure verbose output (what information TaskWarrior displays)
   - Set date format (Y-M-D, M/D/Y, D.M.Y, or custom)

3. **Color Theme**
   - Choose from built-in themes:
     - light-16.theme, light-256.theme
     - dark-16.theme, dark-256.theme
     - dark-red-256.theme, dark-green-256.theme, dark-blue-256.theme
     - solarized-dark-256.theme, solarized-light-256.theme
     - no-color.theme

4. **Urgency Coefficients**
   - Adjust priority coefficient (default 6.0)
   - Adjust age coefficient (default 2.0)
   - Adjust tags coefficient (default 1.0)
   - Controls how TaskWarrior calculates task urgency

5. **User Defined Attributes (UDAs)**
   - Add new UDAs with types: string, numeric, date, duration
   - List all existing UDAs with their types and labels
   - Remove UDAs (with confirmation)
   - Examples: estimate, client, priority, cost, etc.

6. **Report Configuration**
   - Information about customizing task list views
   - Refers to TaskWarrior documentation for advanced configuration

**Example Session:**
```bash
$ p-work
✓ Activated profile: work

$ custom task
# or: ww custom tasks

============================================================
         TaskWarrior Configuration Guide
============================================================

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Configuration Menu - Profile: work
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Configure basic settings (editor, confirmation)
  2. Configure display settings (verbose, date format)
  3. Configure color theme
  4. Configure urgency coefficients
  5. Manage User Defined Attributes (UDAs)
  6. Configure reports
  7. View current configuration
  8. Exit

Choose option [1-8]:
```

**UDA Management Example:**
```bash
Choose option [1-8]: 5

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  User Defined Attributes (UDAs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current UDAs:
  timetracked : duration
  crosstrack : string
  license : string
  languages : string
  # ... many more

UDA Management:
  1. Add new UDA
  2. List all UDAs
  3. Remove UDA
  4. Back to main menu

Choose option [1-4]: 1

Enter UDA name (e.g., estimate, client, priority): estimate

UDA types:
  1. string   - Text value
  2. numeric  - Number value
  3. date     - Date value
  4. duration - Time duration

Choose type [1-4]: 4

Enter UDA label (display name): Estimate

✓ Added UDA: estimate (duration)

You can now use: task add ... estimate:2h
```

**Related Documentation:**
- See TaskWarrior documentation: https://taskwarrior.org/docs/
- See `.taskrc` man page: `man taskrc`
- See profile's `.taskrc` file for current configuration
