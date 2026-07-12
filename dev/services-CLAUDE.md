# CLAUDE.md — services/

This file is context for any agent working inside `services/`. Read it before creating or modifying any service script. The full project context is in the root `CLAUDE.md`.

---

## How Service Discovery Works

`bin/ww` routes commands by scanning `services/<category>/` for executable files. When a user runs `ww <category> <command>`, `ww` finds and executes the matching script.

**Override inheritance:** Profile-level services at `profiles/<name>/services/<category>/` shadow global services with the same filename. The profile-level version runs instead. Global version is never called.

**Discovery rules:**
- Script must be executable (`chmod +x`)
- Script must be in `services/<category>/` (one level deep)
- Filename is the subcommand name (e.g., `create-ww-profile.sh` is invoked as part of `ww profile`)
- Scripts are scanned at runtime — no registration required

---

## Service Template Tiers

Choose the appropriate tier. Do not over-engineer.

### Tier 1 — Basic Script
For simple, self-contained services with no template logic and no lib dependency beyond logging.

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../../lib/logging.sh"

usage() {
  echo "Usage: ww <category> <subcommand> [args]"
  echo "Description: one-line description of what this does"
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage && exit 0

# implementation
```

### Tier 2 — With Templates
For services that process YAML templates, prompts, or user-defined configs.

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../../lib/logging.sh"
source "$(dirname "$0")/../../lib/config-loader.sh"

# Load profile-specific template or fall back to global
TEMPLATE_DIR="${WORKWARRIOR_BASE}/templates"
GLOBAL_TEMPLATE_DIR="$(dirname "$0")/../../resources"
```

### Tier 3 — With Libs
For services that use core lib functions (profile management, GitHub sync, export, etc.).

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/core-utils.sh"
source "${LIB_DIR}/profile-manager.sh"
```

**Which tier to use:**
- New simple utility → Tier 1
- Needs config/template loading → Tier 2
- Needs profile operations, GitHub sync, export → Tier 3

---

## Exit Code Contract

Every service must exit with one of these codes. No exceptions.

| Code | Meaning | When to use |
|---|---|---|
| `0` | Success | Operation completed as intended |
| `1` | User error | Bad arguments, missing required input, invalid profile name |
| `2` | System error | Missing dependency, corrupted state, file permission error |

---

## Help String Format

Every service must respond to `--help` and `-h`. Format:

```
Usage: ww <category> <subcommand> [options] [args]

Description: one clear sentence.

Options:
  -h, --help     Show this help
  --flag         Description of flag

Examples:
  ww <category> <subcommand> arg1
  ww <category> <subcommand> --flag
```

This is required for Gate C. A service without a working help string is not complete.

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Script filename | kebab-case, `.sh` extension | `configure-journals.sh` |
| Shell functions | snake_case | `configure_journal_path()` |
| Local variables | snake_case | `local profile_name` |
| Global/exported vars | SCREAMING_SNAKE | `WARRIOR_PROFILE` |
| Category directory | lowercase, hyphenated | `services/custom/`, `services/x-delete/` |

---

## Adding a New Service Category vs Adding to Existing

**Adding to existing category:** Create a new `.sh` file in `services/<category>/`. Make it executable. Add a help string. Done.

**Adding a new category:**
1. Create `services/<new-category>/` directory
2. Create at least one service script (Tier 1 minimum)
3. Add the category to `services/README.md` under the appropriate section
4. Add a `--help` handler that lists subcommands
5. Update root `CLAUDE.md` directory map if the category affects project structure

---

## Profile-Level Override Pattern

A service can be overridden per-profile:

```
profiles/work/services/custom/configure-journals.sh   ← overrides global
services/custom/configure-journals.sh                 ← global fallback
```

When creating a profile-specific override:
- Copy the global service as a starting point
- Only override what needs to differ
- Document why the override exists in a comment at the top

---

## Prohibited Patterns

These are Gate B failures:

```bash
# NEVER: direct write to profile directory
echo "data" > "$WORKWARRIOR_BASE/.task/hooks/hook.sh"

# CORRECT: use lib function
install_profile_hook "$WARRIOR_PROFILE" "hook.sh" "$hook_content"

# NEVER: raw echo for user-facing messages in services
echo "Error: profile not found"

# CORRECT: use logging lib
log_error "Profile not found: ${profile_name}"

# NEVER: relative paths
source "../../lib/logging.sh"

# CORRECT: absolute via SCRIPT_DIR
source "${SCRIPT_DIR}/../../lib/logging.sh"

# NEVER: missing set -euo pipefail
# NEVER: missing --help handler
```

---

## What Docs Agent Must Update When a Service Changes

After any service modification, the Docs agent is responsible for:

1. `services/README.md` — update the category entry if the service's purpose or usage changed
2. Inline `--help` string — must match actual behavior (Gate C)
3. `docs/usage-examples.md` — if the service has user-facing examples there
4. Root `CLAUDE.md` — if the change affects project-wide behavior or fragility markers

Docs agent runs after Verifier sign-off, before the task is marked complete.
