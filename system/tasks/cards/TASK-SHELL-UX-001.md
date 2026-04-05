## TASK-SHELL-UX-001: Shell integration overhaul — re-source safety, dual-rc, bare commands, output cleanup

Goal:                 Multiple shell integration pain points addressed in one batch:
                      1. `source ~/.bashrc` caused `readonly variable` errors on re-source
                      2. Aliases only written to .bashrc, invisible in zsh sessions
                      3. `profile create <name>` gave "Unknown command: create" (no shell wrapper)
                      4. `find` function shadowed system `find` binary
                      5. Stale `ensure_shell_functions()` injected 400-line per-function stubs (old API)
                      6. Auto-activation of deleted `work` profile on terminal open
                      7. Profile creation output was verbose (per-alias lines, duplicate step messages)
                      8. All major commands required `ww` prefix; bare forms either missing or incomplete

Acceptance criteria:  1. `source ~/.bashrc` or `source ~/.zshrc` is a silent no-op after first load.
                      2. All profile/journal/ledger aliases written to both .bashrc and .zshrc.
                      3. `profile create <name>` works; first-profile skips copy prompts.
                      4. `find` renamed to `search`; system find is never shadowed.
                      5. `ensure_shell_functions()` only ensures ww-init.sh source line is present.
                      6. No auto-activation of any profile on terminal open unless user explicitly set it.
                      7. Profile creation output: no per-alias lines, no "already present" noise, no duplicate steps.
                      8. Bare commands available: profile, profiles, journals, ledgers, services, groups,
                         models, extensions, custom, shortcuts, deps, version, search, tasks, times.

Write scope:          /Users/mp/ww/lib/shell-integration.sh
                      /Users/mp/ww/lib/core-utils.sh
                      /Users/mp/ww/bin/ww-init.sh
                      /Users/mp/ww/scripts/create-ww-profile.sh
                      /Users/mp/.bashrc
                      /Users/mp/.zshrc

Tests required:       Manual smoke:
                        source ~/.bashrc  (should be silent)
                        source ~/.zshrc   (should be silent)
                        profile create <name>  (first profile: no copy prompts)
                        journals  (lists only journal names, not config keys)
                        search    (routes to ww find)
                        New terminal: no auto-profile-activation unless intentional

Rollback:             git checkout /Users/mp/ww/lib/shell-integration.sh
                      git checkout /Users/mp/ww/lib/core-utils.sh
                      git checkout /Users/mp/ww/bin/ww-init.sh
                      git checkout /Users/mp/ww/scripts/create-ww-profile.sh

Fragility:            SERIALIZED: lib/shell-integration.sh (all shell functions sourced from here)

Key decisions:
  - Session guard pattern: [[ -n "${WW_INITIALIZED:-}" ]] && return 0 at top of ww-init.sh
  - No `readonly` on any session-indicator variable (re-source causes re-declare error)
  - get_ww_rc_files() is canonical: all alias/config writes loop through this function
  - add_alias_to_section() accepts optional 3rd arg (rc_file) — rc-file-agnostic
  - find() renamed to search() — tool conflict neutralisation
  - ensure_shell_functions() replaced: 400+ lines → 20 lines (source-line check only)
  - mapfile avoided (requires bash 4.0+; macOS system bash is 3.2)
  - Idempotency checks in add_alias_to_section() are silent (no log output)

Status:               complete
