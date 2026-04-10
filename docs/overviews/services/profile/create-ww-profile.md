# services/profile/create-ww-profile.sh

**Type:** Executed service script
**Invoked by:** `ww profile create <name>`, `scripts/create-ww-profile.sh`
**Subservient to:** Profile service (`services/profile/`)

---

## Role

Full profile creation orchestration. Calls `lib/profile-manager.sh` functions in the correct order to create a complete, ready-to-use profile. This is the canonical profile creation path — `manage-profiles.sh` delegates here for the `create` action.

---

## Creation Sequence

```
create_profile(name)
  1. validate_profile_name(name)
  2. profile_exists(name) → error if already exists
  3. create_profile_directories(base)
  4. create_taskrc(base, name)
  5. install_timewarrior_hook(base)
  6. create_journal_config(base, name)
  7. create_ledger_config(base, name)
  8. create_profile_aliases(name)     ← writes p-<name> to rc files
  9. ensure_shell_functions()         ← ensures ww-init.sh source line present
  10. log_success "Profile '<name>' created"
  11. echo "✓ Aliases written → .bashrc .zshrc"
```

Output is signal-only: no per-alias lines, no idempotency notices. Single summary line at the end.

---

## Output Policy

Profile creation output shows component-level progress markers only:
- `🔧 Creating default TaskRC...`
- `✓ .taskrc created at: ...`
- `✓ Aliases written → .bashrc .zshrc`

Suppressed: per-alias detail, "already present" idempotency notices, duplicate step labels. This was fixed in TASK-SHELL-UX-001.

---

## Post-Creation

After `ww profile create work`, the user activates with `p-work`. The profile is immediately usable — all four tools (task, timew, jrnl, hledger) are isolated to the new profile's directories.
