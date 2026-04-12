#!/usr/bin/env bash
set -euo pipefail

# services/remove/remove.sh — Profile removal service
#
# Usage:
#   ww remove <profile> [profile2 ...]          Remove specific profiles (interactive)
#   ww remove --keep <profile> [profile2 ...]   Remove all EXCEPT listed profiles
#   ww remove --all                             Remove all profiles (interactive)
#   ww remove --list                            Show what would be removed
#
# Each profile is prompted: [a]rchive, [d]elete, or [s]kip
# Archive moves to profiles/.archive/<name>-<timestamp>/
# Delete permanently removes all data.
#
# Flags:
#   --archive-all    Archive all targeted profiles without prompting
#   --delete-all     Delete all targeted profiles without prompting
#   --force          Skip confirmation prompts
#   --dry-run        Show what would happen without doing it
#
# Cleanup scope:
#   - profiles/<name>/           Profile directory (archive or delete)
#   - config/groups.yaml         Remove profile from group membership
#   - .state/active_profile      Clear if matches removed profile
#   - .state/last_profile        Clear if matches removed profile
#   - services/questions/*       Profile-specific question templates
#   - Shell RC files             Remove p-<name> aliases
#
# Future: --scramble flag for data obfuscation before deletion (see task card)

WW_BASE="${WW_BASE:-${WORKWARRIOR_BASE:-$HOME/ww}}"
PROFILES_DIR="$WW_BASE/profiles"
ARCHIVE_DIR="$PROFILES_DIR/.archive"
STATE_DIR="$WW_BASE/.state"
GROUPS_FILE="$WW_BASE/config/groups.yaml"
QUESTIONS_DIR="$WW_BASE/services/questions"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_log_info()    { echo "ℹ $*"; }
_log_success() { echo "✓ $*"; }
_log_warning() { echo "⚠ $*"; }
_log_error()   { echo "✗ $*" >&2; }

_list_profiles() {
    local profiles=()
    for d in "$PROFILES_DIR"/*/; do
        [ -d "$d" ] || continue
        local name
        name=$(basename "$d")
        [[ "$name" == ".archive" ]] && continue
        profiles+=("$name")
    done
    printf '%s\n' "${profiles[@]}"
}

_is_active_profile() {
    local name="$1"
    local active=""
    [ -f "$STATE_DIR/active_profile" ] && active=$(cat "$STATE_DIR/active_profile" 2>/dev/null | tr -d '[:space:]')
    [[ "$active" == "$name" ]]
}

_archive_profile() {
    local name="$1"
    local dry_run="${2:-false}"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local dest="$ARCHIVE_DIR/${name}-${ts}"

    if [[ "$dry_run" == "true" ]]; then
        _log_info "[dry-run] Would archive $name → $dest"
        return 0
    fi

    mkdir -p "$ARCHIVE_DIR"
    mv "$PROFILES_DIR/$name" "$dest"
    _log_success "Archived $name → .archive/${name}-${ts}"
}

_delete_profile() {
    local name="$1"
    local dry_run="${2:-false}"

    if [[ "$dry_run" == "true" ]]; then
        _log_info "[dry-run] Would delete $name permanently"
        return 0
    fi

    rm -rf "${PROFILES_DIR:?}/$name"
    _log_success "Deleted $name permanently"
}

_scrub_groups() {
    local name="$1"
    local dry_run="${2:-false}"

    [ -f "$GROUPS_FILE" ] || return 0

    if grep -q "$name" "$GROUPS_FILE" 2>/dev/null; then
        if [[ "$dry_run" == "true" ]]; then
            _log_info "[dry-run] Would remove $name from groups.yaml"
            return 0
        fi
        # Remove lines containing just the profile name as a list item
        local tmp
        tmp=$(mktemp)
        sed "/^[[:space:]]*- ${name}$/d" "$GROUPS_FILE" > "$tmp"
        mv "$tmp" "$GROUPS_FILE"
        _log_success "Removed $name from groups.yaml"
    fi
}

_scrub_state() {
    local name="$1"
    local dry_run="${2:-false}"

    for state_file in "$STATE_DIR/active_profile" "$STATE_DIR/last_profile"; do
        [ -f "$state_file" ] || continue
        local current
        current=$(cat "$state_file" 2>/dev/null | tr -d '[:space:]')
        if [[ "$current" == "$name" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                _log_info "[dry-run] Would clear $(basename "$state_file") (was $name)"
            else
                echo "" > "$state_file"
                _log_success "Cleared $(basename "$state_file") (was $name)"
            fi
        fi
    done
}

_scrub_question_templates() {
    local name="$1"
    local dry_run="${2:-false}"

    # Find profile-specific question files
    local found=0
    while IFS= read -r -d '' f; do
        found=1
        if [[ "$dry_run" == "true" ]]; then
            _log_info "[dry-run] Would remove question template: $f"
        else
            rm -f "$f"
            _log_success "Removed question template: $(basename "$f")"
        fi
    done < <(find "$QUESTIONS_DIR" -maxdepth 2 -name "${name}*" -print0 2>/dev/null)

    # Also check bin/ subdirectory
    if [ -d "$QUESTIONS_DIR/bin" ]; then
        while IFS= read -r -d '' f; do
            found=1
            if [[ "$dry_run" == "true" ]]; then
                _log_info "[dry-run] Would remove question template: $f"
            else
                rm -f "$f"
                _log_success "Removed question template: $(basename "$f")"
            fi
        done < <(find "$QUESTIONS_DIR/bin" -maxdepth 1 -name "${name}*" -print0 2>/dev/null)
    fi
}

_scrub_shell_aliases() {
    local name="$1"
    local dry_run="${2:-false}"

    # Remove p-<name>, j-<name>, l-<name> aliases from shell RC files
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        if grep -q "p-${name}\|alias ${name}=" "$rc" 2>/dev/null; then
            if [[ "$dry_run" == "true" ]]; then
                _log_info "[dry-run] Would remove aliases for $name from $(basename "$rc")"
            else
                local tmp
                tmp=$(mktemp)
                grep -v "p-${name}\|j-${name}\|l-${name}\|alias ${name}=" "$rc" > "$tmp"
                mv "$tmp" "$rc"
                _log_success "Removed aliases for $name from $(basename "$rc")"
            fi
        fi
    done
}

_process_profile() {
    local name="$1"
    local action="$2"  # archive, delete, prompt
    local dry_run="$3"
    local force="$4"

    if [ ! -d "$PROFILES_DIR/$name" ]; then
        _log_warning "Profile '$name' not found, skipping"
        return 0
    fi

    # Determine action
    local chosen="$action"
    if [[ "$chosen" == "prompt" ]]; then
        local active_marker=""
        _is_active_profile "$name" && active_marker=" (ACTIVE)"

        # Count profile contents for context
        local task_count=0 journal_count=0 ledger_size=0
        [ -d "$PROFILES_DIR/$name/.task" ] && task_count=$(find "$PROFILES_DIR/$name/.task" -name "*.sqlite3" -exec ls -la {} \; 2>/dev/null | wc -l | tr -d ' ')
        journal_count=$(find "$PROFILES_DIR/$name/journals" -name "*.txt" 2>/dev/null | wc -l | tr -d ' ')
        ledger_size=$(du -sh "$PROFILES_DIR/$name/ledgers" 2>/dev/null | cut -f1 || echo "0")

        echo ""
        echo "  Profile: $name$active_marker"
        echo "  Journals: $journal_count  Ledger size: $ledger_size"
        printf "  [a]rchive  [d]elete  [s]kip ? "
        read -r choice
        case "$choice" in
            a|A|archive) chosen="archive" ;;
            d|D|delete)  chosen="delete" ;;
            *)           chosen="skip" ;;
        esac
    fi

    case "$chosen" in
        archive)
            _archive_profile "$name" "$dry_run"
            _scrub_groups "$name" "$dry_run"
            _scrub_state "$name" "$dry_run"
            _scrub_question_templates "$name" "$dry_run"
            _scrub_shell_aliases "$name" "$dry_run"
            ;;
        delete)
            if [[ "$force" != "true" && "$dry_run" != "true" ]]; then
                printf "  Permanently delete '$name'? This cannot be undone. [y/N] "
                read -r confirm
                [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { _log_info "Skipped $name"; return 0; }
            fi
            _delete_profile "$name" "$dry_run"
            _scrub_groups "$name" "$dry_run"
            _scrub_state "$name" "$dry_run"
            _scrub_question_templates "$name" "$dry_run"
            _scrub_shell_aliases "$name" "$dry_run"
            ;;
        skip)
            _log_info "Skipped $name"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

_show_help() {
    cat <<'EOF'
ww remove — Profile removal service

Usage:
  ww remove <profile> [profile2 ...]          Remove specific profiles
  ww remove --keep <profile> [profile2 ...]   Remove all EXCEPT listed
  ww remove --all                             Remove all profiles
  ww remove --list                            Show removable profiles

Options:
  --archive-all    Archive all targeted profiles (no per-profile prompt)
  --delete-all     Delete all targeted profiles (no per-profile prompt)
  --force          Skip confirmation prompts
  --dry-run        Show what would happen without doing it
  --help           Show this help

Each profile is prompted: [a]rchive, [d]elete, or [s]kip
Archive moves to profiles/.archive/<name>-<timestamp>/
Delete permanently removes all data.

Future: --scramble for data obfuscation before deletion
EOF
}

main() {
    local mode=""          # "remove", "keep", "all", "list"
    local action="prompt"  # "prompt", "archive", "delete"
    local dry_run="false"
    local force="false"
    local targets=()

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep)        mode="keep"; shift ;;
            --all)         mode="all"; shift ;;
            --list)        mode="list"; shift ;;
            --archive-all) action="archive"; shift ;;
            --delete-all)  action="delete"; shift ;;
            --force)       force="true"; shift ;;
            --dry-run)     dry_run="true"; shift ;;
            --help|-h)     _show_help; return 0 ;;
            --scramble)    _log_warning "--scramble not yet implemented (flagged for future)"; shift ;;
            -*)            _log_error "Unknown flag: $1"; _show_help; return 1 ;;
            *)             targets+=("$1"); shift ;;
        esac
    done

    # Resolve mode
    if [[ -z "$mode" ]]; then
        if [[ ${#targets[@]} -gt 0 ]]; then
            mode="remove"
        else
            _show_help
            return 1
        fi
    fi

    # Get all profiles
    local all_profiles
    mapfile -t all_profiles < <(_list_profiles)

    if [[ ${#all_profiles[@]} -eq 0 ]]; then
        _log_info "No profiles found"
        return 0
    fi

    # Build removal list
    local to_process=()
    case "$mode" in
        list)
            echo "Profiles:"
            for p in "${all_profiles[@]}"; do
                local marker=""
                _is_active_profile "$p" && marker=" (active)"
                echo "  $p$marker"
            done
            return 0
            ;;
        remove)
            to_process=("${targets[@]}")
            ;;
        keep)
            for p in "${all_profiles[@]}"; do
                local keep=false
                for k in "${targets[@]}"; do
                    [[ "$p" == "$k" ]] && keep=true
                done
                [[ "$keep" == "false" ]] && to_process+=("$p")
            done
            ;;
        all)
            to_process=("${all_profiles[@]}")
            ;;
    esac

    if [[ ${#to_process[@]} -eq 0 ]]; then
        _log_info "No profiles to process"
        return 0
    fi

    # Summary
    echo "Profiles to process: ${to_process[*]}"
    [[ "$dry_run" == "true" ]] && echo "(dry run — no changes will be made)"
    echo ""

    # Process each
    for name in "${to_process[@]}"; do
        _process_profile "$name" "$action" "$dry_run" "$force"
    done

    echo ""
    _log_success "Done"
}

main "$@"
