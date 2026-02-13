#!/usr/bin/env bash
# GitHub Sync CLI Interface
# Command-line interface for GitHub two-way sync

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")/lib"

# Source dependencies
source "${LIB_DIR}/config-loader.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/github-api.sh"
source "${LIB_DIR}/taskwarrior-api.sh"
source "${LIB_DIR}/github-sync-state.sh"
source "${LIB_DIR}/sync-pull.sh"
source "${LIB_DIR}/sync-push.sh"
source "${LIB_DIR}/sync-bidirectional.sh"

# Display help
cmd_help() {
    local subcommand="$1"
    
    if [[ -n "${subcommand}" ]]; then
        case "${subcommand}" in
            enable)
                cat << 'EOF'
Usage: github-sync enable <task-id> <issue-number> <repo>

Enable GitHub sync for a task by linking it to a GitHub issue.

Arguments:
  task-id        TaskWarrior task ID or UUID
  issue-number   GitHub issue number
  repo           GitHub repository (format: owner/repo)

Examples:
  github-sync enable 42 123 myorg/myrepo
  github-sync enable abc123de 456 username/project

This will:
  - Link the task to the GitHub issue
  - Set the githubsync UDA to "enabled"
  - Populate GitHub metadata UDAs
  - Perform an initial pull from GitHub
EOF
                ;;
            disable)
                cat << 'EOF'
Usage: github-sync disable <task-id>

Disable GitHub sync for a task.

Arguments:
  task-id   TaskWarrior task ID or UUID

Examples:
  github-sync disable 42
  github-sync disable abc123de

This will:
  - Set the githubsync UDA to "disabled"
  - Remove sync state (but preserve GitHub metadata UDAs)
EOF
                ;;
            push)
                cat << 'EOF'
Usage: github-sync push [task-id] [--dry-run]

Push task changes to GitHub.

Arguments:
  task-id    (Optional) TaskWarrior task ID or UUID
             If omitted, pushes all synced tasks

Options:
  --dry-run  Show what would be pushed without making changes

Examples:
  github-sync push              # Push all synced tasks
  github-sync push 42           # Push specific task
  github-sync push --dry-run    # Preview changes
EOF
                ;;
            pull)
                cat << 'EOF'
Usage: github-sync pull [task-id] [--dry-run]

Pull issue changes from GitHub.

Arguments:
  task-id    (Optional) TaskWarrior task ID or UUID
             If omitted, pulls all synced tasks

Options:
  --dry-run  Show what would be pulled without making changes

Examples:
  github-sync pull              # Pull all synced issues
  github-sync pull 42           # Pull specific task
  github-sync pull --dry-run    # Preview changes
EOF
                ;;
            sync)
                cat << 'EOF'
Usage: github-sync sync [task-id] [--dry-run]

Bidirectional sync between TaskWarrior and GitHub.

Arguments:
  task-id    (Optional) TaskWarrior task ID or UUID
             If omitted, syncs all synced tasks

Options:
  --dry-run  Show what would be synced without making changes

Examples:
  github-sync sync              # Sync all tasks
  github-sync sync 42           # Sync specific task
  github-sync sync --dry-run    # Preview changes

This will:
  - Detect changes on both sides
  - Resolve conflicts using last-write-wins
  - Push or pull as needed
EOF
                ;;
            status)
                cat << 'EOF'
Usage: github-sync status

Display sync status for all synced tasks.

Examples:
  github-sync status

Shows:
  - Task UUID and description
  - Linked GitHub issue
  - Last sync time
  - Pending changes (if any)
EOF
                ;;
            *)
                echo "Unknown command: ${subcommand}"
                echo "Run 'github-sync help' for available commands"
                return 1
                ;;
        esac
        return 0
    fi
    
    # General help
    cat << 'EOF'
GitHub Sync - Bidirectional sync between TaskWarrior and GitHub

Usage: github-sync <command> [options]

Commands:
  enable <task-id> <issue> <repo>   Link task to GitHub issue
  disable <task-id>                 Unlink task from GitHub
  push [task-id] [--dry-run]        Push changes to GitHub
  pull [task-id] [--dry-run]        Pull changes from GitHub
  sync [task-id] [--dry-run]        Bidirectional sync
  status                            Show sync status
  help [command]                    Show help for a command

Examples:
  github-sync enable 42 123 owner/repo
  github-sync push
  github-sync pull 42
  github-sync sync --dry-run
  github-sync status

For detailed help on a command:
  github-sync help <command>

Documentation:
  See docs/manual-testing-guide.md for more information
EOF
    
    return 0
}

# Enable sync for a task
cmd_enable() {
    local task_id="$1"
    local issue_number="$2"
    local repo="$3"
    
    if [[ -z "${task_id}" || -z "${issue_number}" || -z "${repo}" ]]; then
        echo "Error: task-id, issue-number, and repo required" >&2
        echo "Usage: github-sync enable <task-id> <issue-number> <repo>" >&2
        return 1
    fi
    
    # Get task UUID
    local task_uuid
    task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: Task '${task_id}' not found" >&2
        return 1
    fi
    
    echo "Enabling sync for task ${task_uuid:0:8}..." >&2
    
    # Set GitHub metadata
    tw_update_task "${task_uuid}" "githubissue" "${issue_number}"
    tw_update_task "${task_uuid}" "githubrepo" "${repo}"
    tw_update_task "${task_uuid}" "githubsync" "enabled"
    
    # Perform initial pull
    echo "Performing initial pull..." >&2
    if sync_pull_issue "${task_uuid}" "${issue_number}" "${repo}"; then
        echo "✓ Sync enabled for task ${task_uuid:0:8} → issue #${issue_number}" >&2
        return 0
    else
        echo "✗ Failed to perform initial pull" >&2
        return 1
    fi
}

# Disable sync for a task
cmd_disable() {
    local task_id="$1"
    
    if [[ -z "${task_id}" ]]; then
        echo "Error: task-id required" >&2
        echo "Usage: github-sync disable <task-id>" >&2
        return 1
    fi
    
    # Get task UUID
    local task_uuid
    task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
    
    if [[ -z "${task_uuid}" ]]; then
        echo "Error: Task '${task_id}' not found" >&2
        return 1
    fi
    
    echo "Disabling sync for task ${task_uuid:0:8}..." >&2
    
    # Set githubsync to disabled
    tw_update_task "${task_uuid}" "githubsync" "disabled"
    
    # Remove sync state
    remove_sync_state "${task_uuid}"
    
    echo "✓ Sync disabled for task ${task_uuid:0:8}" >&2
    return 0
}

# Push command
cmd_push() {
    local task_id=""
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                task_id="$1"
                shift
                ;;
        esac
    done
    
    if [[ "${dry_run}" != "true" ]] && ! check_gh_cli; then
        return 1
    fi

    if [[ "${dry_run}" == "true" ]]; then
        if [[ -n "${task_id}" ]]; then
            local task_uuid state issue_number repo
            task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
            [[ -z "${task_uuid}" ]] && { echo "Error: Task '${task_id}' not found" >&2; return 1; }
            state=$(get_sync_state "${task_uuid}")
            [[ -z "${state}" ]] && { echo "Error: Task ${task_uuid:0:8} is not synced" >&2; return 1; }
            issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
            repo=$(echo "${state}" | jq -r '.github_repo // ""')
            echo "DRY RUN: Would push task ${task_uuid:0:8} → ${repo}#${issue_number}" >&2
        else
            local synced_count
            synced_count=$(get_all_synced_tasks | grep -c . || true)
            echo "DRY RUN: Would push ${synced_count} synced task(s) to GitHub" >&2
        fi
        return 0
    fi
    
    if [[ -n "${task_id}" ]]; then
        # Push single task
        local task_uuid
        task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
        
        if [[ -z "${task_uuid}" ]]; then
            echo "Error: Task '${task_id}' not found" >&2
            return 1
        fi
        
        # Get sync state
        local state
        state=$(get_sync_state "${task_uuid}")
        
        if [[ -z "${state}" ]]; then
            echo "Error: Task ${task_uuid:0:8} is not synced" >&2
            return 1
        fi
        
        local issue_number repo
        issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
        repo=$(echo "${state}" | jq -r '.github_repo // ""')
        
        sync_push_task "${task_uuid}" "${issue_number}" "${repo}"
    else
        # Push all tasks
        sync_push_all
    fi
}

# Pull command
cmd_pull() {
    local task_id=""
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                task_id="$1"
                shift
                ;;
        esac
    done
    
    if [[ "${dry_run}" != "true" ]] && ! check_gh_cli; then
        return 1
    fi

    if [[ "${dry_run}" == "true" ]]; then
        if [[ -n "${task_id}" ]]; then
            local task_uuid state issue_number repo
            task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
            [[ -z "${task_uuid}" ]] && { echo "Error: Task '${task_id}' not found" >&2; return 1; }
            state=$(get_sync_state "${task_uuid}")
            [[ -z "${state}" ]] && { echo "Error: Task ${task_uuid:0:8} is not synced" >&2; return 1; }
            issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
            repo=$(echo "${state}" | jq -r '.github_repo // ""')
            echo "DRY RUN: Would pull ${repo}#${issue_number} → task ${task_uuid:0:8}" >&2
        else
            local synced_count
            synced_count=$(get_all_synced_tasks | grep -c . || true)
            echo "DRY RUN: Would pull updates for ${synced_count} synced task(s)" >&2
        fi
        return 0
    fi
    
    if [[ -n "${task_id}" ]]; then
        # Pull single task
        local task_uuid
        task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
        
        if [[ -z "${task_uuid}" ]]; then
            echo "Error: Task '${task_id}' not found" >&2
            return 1
        fi
        
        # Get sync state
        local state
        state=$(get_sync_state "${task_uuid}")
        
        if [[ -z "${state}" ]]; then
            echo "Error: Task ${task_uuid:0:8} is not synced" >&2
            return 1
        fi
        
        local issue_number repo
        issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
        repo=$(echo "${state}" | jq -r '.github_repo // ""')
        
        sync_pull_issue "${task_uuid}" "${issue_number}" "${repo}"
    else
        # Pull all tasks
        sync_pull_all
    fi
}

# Sync command
cmd_sync() {
    local task_id=""
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                task_id="$1"
                shift
                ;;
        esac
    done
    
    if [[ "${dry_run}" != "true" ]] && ! check_gh_cli; then
        return 1
    fi

    if [[ "${dry_run}" == "true" ]]; then
        if [[ -n "${task_id}" ]]; then
            local task_uuid
            task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
            [[ -z "${task_uuid}" ]] && { echo "Error: Task '${task_id}' not found" >&2; return 1; }
            echo "DRY RUN: Would bidirectionally sync task ${task_uuid:0:8}" >&2
        else
            local synced_count
            synced_count=$(get_all_synced_tasks | grep -c . || true)
            echo "DRY RUN: Would bidirectionally sync ${synced_count} synced task(s)" >&2
        fi
        return 0
    fi
    
    if [[ -n "${task_id}" ]]; then
        # Sync single task
        local task_uuid
        task_uuid=$(task _get "${task_id}.uuid" 2>/dev/null)
        
        if [[ -z "${task_uuid}" ]]; then
            echo "Error: Task '${task_id}' not found" >&2
            return 1
        fi
        
        sync_task_bidirectional "${task_uuid}"
    else
        # Sync all tasks
        sync_all_tasks
    fi
}

# Status command
cmd_status() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "GitHub Sync Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Get all synced tasks
    local synced_tasks
    synced_tasks=$(get_all_synced_tasks)
    
    if [[ -z "${synced_tasks}" ]]; then
        echo "No synced tasks found"
        return 0
    fi
    
    local count=0
    
    while IFS= read -r task_uuid; do
        if [[ -z "${task_uuid}" ]]; then
            continue
        fi
        
        count=$((count + 1))
        
        # Get task data
        local task_data
        task_data=$(tw_get_task "${task_uuid}" 2>/dev/null)
        
        if [[ -z "${task_data}" ]]; then
            continue
        fi
        
        # Get sync state
        local state
        state=$(get_sync_state "${task_uuid}")
        
        local description issue_number repo last_sync
        description=$(echo "${task_data}" | jq -r '.description // ""')
        issue_number=$(echo "${state}" | jq -r '.github_issue // ""')
        repo=$(echo "${state}" | jq -r '.github_repo // ""')
        last_sync=$(echo "${state}" | jq -r '.last_sync // ""')
        
        echo "Task: ${task_uuid:0:8}"
        echo "  Description: ${description}"
        echo "  GitHub: ${repo}#${issue_number}"
        echo "  Last sync: ${last_sync}"
        echo ""
        
    done <<< "${synced_tasks}"
    
    echo "Total synced tasks: ${count}"
    
    return 0
}

# Main entry point
main() {
    # Check for profile
    if [[ -z "${WORKWARRIOR_BASE}" ]]; then
        echo "Error: No profile active. Please activate a profile first." >&2
        echo "Run: p-<profile-name> (or use_task_profile <profile-name>)" >&2
        return 1
    fi
    
    # Load configuration
    if ! init_github_sync_config; then
        echo "Error: Failed to load configuration" >&2
        return 1
    fi
    
    # Initialize logging
    if ! init_logging; then
        echo "Warning: Failed to initialize logging" >&2
    fi
    
    # Rotate logs if needed
    rotate_logs
    
    # Parse command
    local command="$1"
    shift
    
    case "${command}" in
        enable|enable-sync)
            if ! check_gh_cli; then
                return 1
            fi
            cmd_enable "$@"
            ;;
        disable|disable-sync)
            cmd_disable "$@"
            ;;
        push)
            cmd_push "$@"
            ;;
        pull)
            cmd_pull "$@"
            ;;
        sync)
            cmd_sync "$@"
            ;;
        status|sync-status)
            cmd_status "$@"
            ;;
        help|--help|-h|"")
            cmd_help "$@"
            ;;
        *)
            echo "Error: Unknown command '${command}'" >&2
            echo "Run 'github-sync help' for available commands" >&2
            return 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
