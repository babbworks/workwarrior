# Service Development Guide

This guide describes how to create and register services in Workwarrior.

## Service Locations

Global services:
- `~/ww/services/<category>/`

Profile-specific services:
- `<profile-base>/services/<category>/`

When a profile is active, profile-specific services override global services of the same name.

## Categories

Service categories are simple directories under `services/`. New categories can be added by creating a directory and placing scripts inside it.

## Service Script Template

```bash
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

if [[ -z "$WORKWARRIOR_BASE" ]]; then
  log_error "No active profile. Activate a profile first."
  exit 1
fi

main() {
  log_info "Running my service..."
}

main "$@"
```

## Templates and Handlers

If your service needs templates and processing:

```
services/my-service/
├── templates/
├── handlers/
└── lib/
```

## Best Practices

1. Use `set -e` for fail-fast behavior.
2. Validate all arguments before use.
3. Prefer absolute paths.
4. Log errors with `log_error`.
5. Keep services small; share logic in `lib/`.
