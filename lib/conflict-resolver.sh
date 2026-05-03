#!/usr/bin/env bash
# Conflict Resolver
# Resolves conflicts when both sides changed

# Compare timestamps
# Input: task_modified (ISO 8601), github_updated (ISO 8601)
# Output: result (task_newer|github_newer|equal) to stdout
# Returns: 0 on success
compare_timestamps() {
    local task_modified="$1"
    local github_updated="$2"
    
    if [[ -z "${task_modified}" || -z "${github_updated}" ]]; then
        echo "Error: Both timestamps required" >&2
        return 1
    fi
    
    # Convert ISO 8601 timestamps to Unix epoch for comparison
    local task_epoch github_epoch
    
    # macOS date command syntax
    if date -j -f "%Y%m%dT%H%M%SZ" "${task_modified//[-:]/}" "+%s" 2>/dev/null >/dev/null; then
        # TaskWarrior format: 20240115T103000Z
        task_epoch=$(date -j -f "%Y%m%dT%H%M%SZ" "${task_modified//[-:]/}" "+%s" 2>/dev/null)
    else
        # Try ISO 8601 format: 2024-01-15T10:30:00Z
        task_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${task_modified}" "+%s" 2>/dev/null)
    fi
    
    # GitHub format: 2024-01-15T10:30:00Z
    github_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${github_updated}" "+%s" 2>/dev/null)
    
    if [[ -z "${task_epoch}" || -z "${github_epoch}" ]]; then
        echo "Error: Failed to parse timestamps" >&2
        return 1
    fi
    
    if [[ ${task_epoch} -gt ${github_epoch} ]]; then
        echo "task_newer"
    elif [[ ${task_epoch} -lt ${github_epoch} ]]; then
        echo "github_newer"
    else
        echo "equal"
    fi
    
    return 0
}

# Resolve conflict using last-write-wins
# Input: task_uuid, task_data (JSON), github_data (JSON)
# Output: action (push|pull) to stdout
# Returns: 0 on success
resolve_conflict_last_write_wins() {
    local task_uuid="$1"
    local task_data="$2"
    local github_data="$3"
    
    if [[ -z "${task_uuid}" || -z "${task_data}" || -z "${github_data}" ]]; then
        echo "Error: task_uuid, task_data, and github_data required" >&2
        return 1
    fi
    
    # Extract timestamps
    local task_modified github_updated
    task_modified=$(echo "${task_data}" | jq -r '.modified // ""')
    github_updated=$(echo "${github_data}" | jq -r '.updatedAt // ""')
    
    if [[ -z "${task_modified}" || -z "${github_updated}" ]]; then
        echo "Error: Missing timestamps in data" >&2
        return 1
    fi
    
    # Compare timestamps
    local comparison
    comparison=$(compare_timestamps "${task_modified}" "${github_updated}")
    
    case "${comparison}" in
        task_newer)
            # Task was modified more recently - push to GitHub
            echo "push"
            ;;
        github_newer)
            # GitHub was updated more recently - pull from GitHub
            echo "pull"
            ;;
        equal)
            # Timestamps are equal - prefer GitHub (tiebreaker)
            echo "pull"
            ;;
        *)
            echo "Error: Unknown comparison result '${comparison}'" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Log conflict resolution
# Input: task_uuid, strategy (string), winner (task|github), task_modified, github_updated
# Output: Writes to error log
# Returns: 0 on success
log_conflict_resolution() {
    local task_uuid="$1"
    local strategy="$2"
    local winner="$3"
    local task_modified="$4"
    local github_updated="$5"
    
    if [[ -z "${WORKWARRIOR_BASE}" ]]; then
        echo "Error: WORKWARRIOR_BASE not set" >&2
        return 1
    fi
    
    local log_dir="${WORKWARRIOR_BASE}/.task/github-sync"
    local error_log="${log_dir}/errors.log"
    
    # Ensure log directory exists
    mkdir -p "${log_dir}"
    
    # Create log entry
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local log_entry
    log_entry=$(jq -n \
        --arg ts "${timestamp}" \
        --arg uuid "${task_uuid}" \
        --arg strategy "${strategy}" \
        --arg winner "${winner}" \
        --arg task_mod "${task_modified}" \
        --arg gh_upd "${github_updated}" \
        '{
            timestamp: $ts,
            type: "conflict_resolution",
            task_uuid: $uuid,
            strategy: $strategy,
            winner: $winner,
            task_modified: $task_mod,
            github_updated: $gh_upd
        }')
    
    # Append to log file
    echo "${log_entry}" >> "${error_log}"
    
    return 0
}
