#!/usr/bin/env bash
# lib/ledger-dispatch.sh — the shared ww ledger / l dispatcher.
#
# Model (see logs/decisions.md 2026-07-12): a small set of reserved management
# words (ww owns ledgers.yaml), and everything else passes through to
# `hledger -f "$LEDGER_F"` (hledger owns every *.journal, in its true state).
#
# Sourced by BOTH cmd_ledger (bin/ww) and the `l` shell function — one owner,
# thin callers, so the two surfaces cannot drift apart.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.
# Depends (present in both callers' context): log_error/log_success (core-utils),
# add_ledger_to_profile/remove_ledger_from_profile/rename_ledger_in_profile
# (profile-manager), ledger_cfg_* (ledger-config).

# Resolve the active profile's default ledger file. 0 extra processes when the
# session-exported LEDGER_F is set; falls back to the schema owner otherwise.
_ledger_default_file() {
  if [[ -n "${LEDGER_F:-}" ]]; then
    printf '%s\n' "$LEDGER_F"
    return 0
  fi
  ledger_cfg_default_path 2>/dev/null
}

# Pass arguments through to hledger against a target ledger file.
# An explicit -f/--file in the args bypasses target injection.
#   _ledger_passthrough <target-file> <hledger-args...>
_ledger_passthrough() {
  local target="$1"; shift 2>/dev/null || true
  if ! command -v hledger >/dev/null 2>&1; then
    log_error "hledger is not installed or not in PATH"
    return 1
  fi
  # TASK-LED-013: this is THE arbitrary-flag surface — a user can hand hledger -X/--value
  # here, and a below-floor hledger does not error on them, it returns UNCONVERTED numbers.
  # Guard it. The floor is owned by lib/hledger-version.sh; do NOT reimplement it here.
  # Absent-safe: a no-op if the floor lib is not loaded.
  if declare -F hledger_require_floor >/dev/null 2>&1; then
    hledger_require_floor || return 2
  fi
  local has_file=0 arg
  for arg in "$@"; do
    [[ "$arg" == "-f" || "$arg" == "--file" ]] && has_file=1
  done
  if [[ $has_file -eq 0 && -n "$target" && -f "$target" ]]; then
    command hledger -f "$target" "$@"
  else
    command hledger "$@"
  fi
}

# ── TASK-LED-016: WRITE-BACK REFUSAL ──────────────────────────────────────────
#
# THE HAZARD (verified): `print --auto` output MUST NEVER be piped back into a
# journal that still holds the auto-rule. The rule fires again on the derived
# posting: 1.2h becomes 2.4h. This is the single worst data-corruption bug this
# system can produce: it silently double-counts work history.
#
# This function REFUSES to write content containing auto-expanded postings into
# any file inside the profile's ledger tree. It is the gatekeeper. Any ww code
# path that might materialise auto output MUST call this before writing.
#
# Returns 0 if writing is safe, 1 if refused.
ledger_refuse_auto_writeback() {
  local content="$1"
  local target_file="${2:-}"

  # Refuse if the content appears to contain auto-expanded postings
  # (the --auto flag materialises rules into plain postings, so we can't
  # always detect them. But we CAN refuse if the caller declares --auto was used.)
  if [[ "${_LEDGER_AUTO_ACTIVE:-}" == "1" ]]; then
    log_error "REFUSED: cannot write --auto/--forecast output back into the ledger tree."
    log_error "The auto rule would fire again on the derived postings (double-count hazard)."
    log_error "Use 'ww ledger explain' to VIEW the computed state. It is read-only."
    return 1
  fi

  # Also refuse if target is inside the ledger tree and content smells like
  # materialised auto output (belt-and-suspenders)
  if [[ -n "$target_file" && -n "${WORKWARRIOR_BASE:-}" ]]; then
    local ledger_dir="${WORKWARRIOR_BASE}/ledgers"
    if [[ "$target_file" == "$ledger_dir"* ]]; then
      # Check if content has the telltale of auto-expanded rules
      if echo "$content" | grep -qE 'backlog:|accrued-' 2>/dev/null; then
        if [[ "${_LEDGER_WRITEBACK_FORCE:-}" != "1" ]]; then
          log_error "REFUSED: content appears to contain auto-derived postings."
          log_error "Writing it into the ledger tree would cause double-counting."
          return 1
        fi
      fi
    fi
  fi

  return 0
}

# Resolve the passthrough target file for an optional selected ledger name.
# With a name: resolve via the schema owner (error if unknown / no active
# profile). Without: the profile default (0 extra processes when LEDGER_F is set).
_ledger_target() {
  local sel="${1:-}"
  if [[ -n "$sel" ]]; then
    if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
      log_error "No active profile; named ledgers are per-profile."
      return 1
    fi
    local p; p="$(ledger_cfg_resolve "$sel" 2>/dev/null || true)"
    if [[ -z "$p" ]]; then
      log_error "Ledger not found: $sel"
      return 1
    fi
    printf '%s\n' "$p"
  else
    _ledger_default_file
  fi
}

# ledger_dispatch <action> [args...]
# Reserved management words act on the ledgers.yaml registry; everything else
# passes through to hledger. Returns the underlying command's exit code.
ledger_dispatch() {
  # Optional leading named-ledger selector (passthrough-only; management ignores it).
  local sel_ledger=""
  case "${1:-}" in
    -L|--ledger) sel_ledger="${2:-}"; shift 2 2>/dev/null || true ;;
    --ledger=*)  sel_ledger="${1#--ledger=}"; shift ;;
  esac

  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    new|create)
      if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        log_error "No active profile. Activate one with p-<profile-name>."
        return 1
      fi
      local _new_name="${1:-}"
      if [[ -z "$_new_name" ]]; then
        log_error "Ledger name required"
        echo "Usage: ww ledger new <name>"
        return 1
      fi
      if ledger_cfg_exists "$_new_name"; then
        log_error "Ledger '$_new_name' already exists"
        return 1
      fi
      local _new_file="$WORKWARRIOR_BASE/ledgers/${_new_name}.journal"
      mkdir -p "$WORKWARRIOR_BASE/ledgers"
      [[ -f "$_new_file" ]] || printf '; %s ledger — created %s\n' "$_new_name" "$(date +%Y-%m-%d)" > "$_new_file"
      if ledger_cfg_add "$_new_name" "$_new_file"; then
        log_success "Created ledger '$_new_name' at $_new_file"
      else
        log_error "Failed to register ledger '$_new_name'"
        return 1
      fi
      ;;
    remove|delete|rm)
      if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        log_error "No active profile. Activate one with p-<profile-name>."
        return 1
      fi
      local _rm_name="${1:-}"
      if [[ -z "$_rm_name" ]]; then
        log_error "Ledger name required"
        echo "Usage: ww ledger remove <name>"
        return 1
      fi
      local _rm_path; _rm_path="$(ledger_cfg_resolve "$_rm_name" 2>/dev/null || true)"
      if ledger_cfg_remove "$_rm_name"; then
        [[ -n "$_rm_path" && -f "$_rm_path" ]] && rm -f "$_rm_path"
        log_success "Removed ledger '$_rm_name'"
      else
        return 1
      fi
      ;;
    rename)
      if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        log_error "No active profile. Activate one with p-<profile-name>."
        return 1
      fi
      if [[ -z "${1:-}" || -z "${2:-}" ]]; then
        log_error "Old and new ledger names required"
        echo "Usage: ww ledger rename <old> <new>"
        return 1
      fi
      # Registry-key rename (the file keeps its name; the schema owner is the
      # single source of truth for name -> path).
      if ledger_cfg_rename "$1" "$2"; then
        log_success "Renamed ledger '$1' -> '$2'"
      else
        return 1
      fi
      ;;
    list)
      local names=()
      mapfile -t names < <(ledger_cfg_names)
      if (( ${#names[@]} > 0 )); then
        printf '%s\n' "${names[@]}"
      fi
      ;;
    set-default|set-default-ledger)
      if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        log_error "No active profile. Activate one with p-<profile-name>."
        return 1
      fi
      if [[ -z "${1:-}" ]]; then
        log_error "Ledger name required"
        echo "Usage: ww ledger set-default <name>"
        return 1
      fi
      if ledger_cfg_set_default "$1"; then
        log_success "Default ledger set to '$1'"
      else
        log_error "Ledger not found: $1"
        return 1
      fi
      ;;
    inventory)
      bash "${WW_BASE:-$HOME/ww}/scripts/build-ledger-inventory.sh" "$@"
      ;;
    custom)
      "${WW_BASE:-$HOME/ww}/services/custom/configure-ledgers.sh" "$@"
      ;;
    help|-h|--help)
      if declare -f show_help_ledger >/dev/null 2>&1; then
        show_help_ledger
      else
        echo "ww ledger: reserved words new|remove|rename|list|set-default|inventory|custom|task; all else passes through to hledger"
      fi
      ;;
    "")
      # Bare invocation → a balance overview of the (selected or default) ledger.
      local _t; _t="$(_ledger_target "$sel_ledger")" || return 1
      _ledger_passthrough "$_t" balance
      ;;
    *)
      # Anything hledger understands, on the selected or default ledger.
      local _t; _t="$(_ledger_target "$sel_ledger")" || return 1
      _ledger_passthrough "$_t" "$action" "$@"
      ;;
  esac
}
