#!/usr/bin/env bash
# Two-Way Sync Service - Prototype Shell Implementation
# ======================================================
#
# This is an EXPLORATORY PROTOTYPE demonstrating how a two-way sync
# service could be implemented using shell scripts and TaskWarrior hooks.
#
# NOTE: This is NOT production code - it's a proof of concept.

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

SYNC_DIR="${HOME}/.task/sync"
STATE_DB="${SYNC_DIR}/state.json"
QUEUE_DIR="${SYNC_DIR}/queue"
CONFLICT_DIR="${SYNC_DIR}/conflicts"
LOG_FILE="${SYNC_DIR}/sync.log"

# Sync settings
SYNC_STRATEGY="${SYNC_STRATEGY:-last_write_wins}"  # last_write_wins, manual, merge
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"  # 5 minutes
DRY_RUN="${DRY_RUN:-0}"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_sync_service() {
    echo "Initializing two-way sync service..."
    
    # Create directories
    mkdir -p "$SYNC_DIR" "$QUEUE_DIR" "$CONFLICT_DIR"
    
    # Initialize state database
    if [[ ! -f "$STATE_DB" ]]; then
        echo '{}' > "$STATE_DB"
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
    echo "Sync service initialized at: $SYNC_DIR"
}

log_message() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

get_task_state() {
    local task_uuid="$1"
    
    # Get current task state from TaskWarrior
    task "$task_uuid" export | jq -r '.[0]'
}

get_sync_state() {
    local task_uuid="$1"
    
    # Get sync state from database
    jq -r ".\"$task_uuid\" // null" "$STATE_DB"
}

save_sync_state() {
    local task_uuid="$1"
    local state="$2"
    
    # Update state database
    local tmp_file="${STATE_DB}.tmp"
    jq ".\"$task_uuid\" = $state" "$STATE_DB" > "$tmp_file"
    mv "$tmp_file" "$STATE_DB"
}

calculate_checksum() {
    local data="$1"
    echo -n "$data" | sha256sum | awk '{print $1}'
}

# ============================================================================
# CHANGE DETECTION
# ============================================================================

detect_changes() {
    local old_state="$1"
    local new_state="$2"
    
    # Compare states and return changed fields
    local changes="{}"
    
    # Check description
    local old_desc=$(echo "$old_state" | jq -r '.description')
    local new_desc=$(echo "$new_state" | jq -r '.description')
    if [[ "$old_desc" != "$new_desc" ]]; then
        changes=$(echo "$changes" | jq ".description = {\"old\": \"$old_desc\", \"new\": \"$new_desc\"}")
    fi
    
    # Check status
    local old_status=$(echo "$old_state" | jq -r '.status')
    local new_status=$(echo "$new_state" | jq -r '.status')
    if [[ "$old_status" != "$new_status" ]]; then
        changes=$(echo "$changes" | jq ".status = {\"old\": \"$old_status\", \"new\": \"$new_status\"}")
    fi
    
    # Check priority
    local old_priority=$(echo "$old_state" | jq -r '.priority // ""')
    local new_priority=$(echo "$new_state" | jq -r '.priority // ""')
    if [[ "$old_priority" != "$new_priority" ]]; then
        changes=$(echo "$changes" | jq ".priority = {\"old\": \"$old_priority\", \"new\": \"$new_priority\"}")
    fi
    
    echo "$changes"
}

has_changes() {
    local changes="$1"
    [[ "$(echo "$changes" | jq 'keys | length')" -gt 0 ]]
}

# ============================================================================
# FIELD MAPPING
# ============================================================================

map_status_to_github() {
    local status="$1"
    case "$status" in
        pending|started) echo "open" ;;
        completed|deleted) echo "closed" ;;
        *) echo "open" ;;
    esac
}

map_github_to_status() {
    local state="$1"
    case "$state" in
        open) echo "pending" ;;
        closed) echo "completed" ;;
        *) echo "pending" ;;
    esac
}

map_priority_to_github() {
    local priority="$1"
    case "$priority" in
        H) echo "high" ;;
        M) echo "medium" ;;
        L) echo "low" ;;
        *) echo "medium" ;;
    esac
}

task_to_github_issue() {
    local task_json="$1"
    
    local title=$(echo "$task_json" | jq -r '.description')
    local status=$(echo "$task_json" | jq -r '.status')
    local priority=$(echo "$task_json" | jq -r '.priority // ""')
    local tags=$(echo "$task_json" | jq -r '.tags // [] | join(",")')
    
    local github_state=$(map_status_to_github "$status")
    local github_priority=$(map_priority_to_github "$priority")
    
    cat <<EOF
{
  "title": "$title",
  "state": "$github_state",
  "labels": ["$tags", "priority:$github_priority"]
}
EOF
}

# ============================================================================
# CONFLICT RESOLUTION
# ============================================================================

detect_conflict() {
    local task_uuid="$1"
    local local_changes="$2"
    local remote_changes="$3"
    
    # Check if same fields changed on both sides
    local local_fields=$(echo "$local_changes" | jq -r 'keys | .[]')
    local remote_fields=$(echo "$remote_changes" | jq -r 'keys | .[]')
    
    for field in $local_fields; do
        if echo "$remote_fields" | grep -q "^${field}$"; then
            return 0  # Conflict detected
        fi
    done
    
    return 1  # No conflict
}

resolve_conflict_last_write_wins() {
    local task_uuid="$1"
    local local_modified="$2"
    local remote_updated="$3"
    
    # Compare timestamps
    if [[ "$local_modified" > "$remote_updated" ]]; then
        echo "push"
    else
        echo "pull"
    fi
}

resolve_conflict_manual() {
    local task_uuid="$1"
    local local_changes="$2"
    local remote_changes="$3"
    
    # Save conflict for manual resolution
    local conflict_file="${CONFLICT_DIR}/${task_uuid}.json"
    cat > "$conflict_file" <<EOF
{
  "task_uuid": "$task_uuid",
  "timestamp": "$(date -Iseconds)",
  "local_changes": $local_changes,
  "remote_changes": $remote_changes
}
EOF
    
    log_message "WARN" "Conflict detected for task $task_uuid - saved to $conflict_file"
    echo "manual"
}

# ============================================================================
# SYNC OPERATIONS
# ============================================================================

push_to_github() {
    local task_uuid="$1"
    local issue_number="$2"
    local changes="$3"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        log_message "INFO" "[DRY RUN] Would push task $task_uuid to GitHub issue #$issue_number"
        log_message "INFO" "[DRY RUN] Changes: $changes"
        return 0
    fi
    
    # Get task data
    local task_json=$(get_task_state "$task_uuid")
    local github_data=$(task_to_github_issue "$task_json")
    
    # Push to GitHub API
    log_message "INFO" "Pushing task $task_uuid to GitHub issue #$issue_number"
    
    # Example GitHub API call (requires gh CLI or curl)
    if command -v gh &> /dev/null; then
        local title=$(echo "$github_data" | jq -r '.title')
        local state=$(echo "$github_data" | jq -r '.state')
        
        gh issue edit "$issue_number" \
            --title "$title" \
            --state "$state" 2>&1 | tee -a "$LOG_FILE"
        
        return $?
    else
        log_message "ERROR" "GitHub CLI (gh) not installed - cannot push"
        return 1
    fi
}

pull_from_github() {
    local task_uuid="$1"
    local issue_number="$2"
    local changes="$3"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        log_message "INFO" "[DRY RUN] Would pull GitHub issue #$issue_number to task $task_uuid"
        log_message "INFO" "[DRY RUN] Changes: $changes"
        return 0
    fi
    
    # Fetch from GitHub API
    log_message "INFO" "Pulling GitHub issue #$issue_number to task $task_uuid"
    
    if command -v gh &> /dev/null; then
        local issue_json=$(gh issue view "$issue_number" --json title,state,labels)
        
        local title=$(echo "$issue_json" | jq -r '.title')
        local state=$(echo "$issue_json" | jq -r '.state')
        local task_status=$(map_github_to_status "$state")
        
        # Update TaskWarrior task
        task "$task_uuid" modify description:"$title" status:"$task_status" 2>&1 | tee -a "$LOG_FILE"
        
        return $?
    else
        log_message "ERROR" "GitHub CLI (gh) not installed - cannot pull"
        return 1
    fi
}

# ============================================================================
# QUEUE MANAGEMENT
# ============================================================================

queue_change() {
    local task_uuid="$1"
    local direction="$2"  # push or pull
    local changes="$3"
    
    local queue_file="${QUEUE_DIR}/${task_uuid}_${direction}_$(date +%s).json"
    
    cat > "$queue_file" <<EOF
{
  "task_uuid": "$task_uuid",
  "direction": "$direction",
  "changes": $changes,
  "queued_at": "$(date -Iseconds)",
  "status": "pending"
}
EOF
    
    log_message "INFO" "Queued $direction for task $task_uuid"
}

process_queue() {
    log_message "INFO" "Processing sync queue..."
    
    local processed=0
    local failed=0
    
    for queue_file in "$QUEUE_DIR"/*.json; do
        [[ -f "$queue_file" ]] || continue
        
        local task_uuid=$(jq -r '.task_uuid' "$queue_file")
        local direction=$(jq -r '.direction' "$queue_file")
        local changes=$(jq -r '.changes' "$queue_file")
        
        log_message "INFO" "Processing: $direction for task $task_uuid"
        
        # Get issue number from sync state
        local sync_state=$(get_sync_state "$task_uuid")
        local issue_number=$(echo "$sync_state" | jq -r '.service_id // ""')
        
        if [[ -z "$issue_number" ]]; then
            log_message "ERROR" "No issue number found for task $task_uuid"
            ((failed++))
            continue
        fi
        
        # Execute sync operation
        if [[ "$direction" == "push" ]]; then
            if push_to_github "$task_uuid" "$issue_number" "$changes"; then
                rm "$queue_file"
                ((processed++))
            else
                ((failed++))
            fi
        elif [[ "$direction" == "pull" ]]; then
            if pull_from_github "$task_uuid" "$issue_number" "$changes"; then
                rm "$queue_file"
                ((processed++))
            else
                ((failed++))
            fi
        fi
    done
    
    log_message "INFO" "Queue processing complete: $processed processed, $failed failed"
}

# ============================================================================
# MAIN SYNC LOGIC
# ============================================================================

sync_task() {
    local task_uuid="$1"
    
    log_message "INFO" "Syncing task: $task_uuid"
    
    # Get current task state
    local current_task=$(get_task_state "$task_uuid")
    if [[ -z "$current_task" || "$current_task" == "null" ]]; then
        log_message "ERROR" "Task $task_uuid not found"
        return 1
    fi
    
    # Get sync state
    local sync_state=$(get_sync_state "$task_uuid")
    
    if [[ -z "$sync_state" || "$sync_state" == "null" ]]; then
        # First sync - initialize
        log_message "INFO" "Initializing sync for task $task_uuid"
        
        local new_state=$(cat <<EOF
{
  "task_uuid": "$task_uuid",
  "service_type": "github",
  "service_id": "",
  "last_sync": "$(date -Iseconds)",
  "last_local_state": $current_task,
  "last_remote_state": null,
  "local_checksum": "$(calculate_checksum "$current_task")",
  "remote_checksum": ""
}
EOF
)
        save_sync_state "$task_uuid" "$new_state"
        return 0
    fi
    
    # Check for changes
    local last_local=$(echo "$sync_state" | jq -r '.last_local_state')
    local local_changes=$(detect_changes "$last_local" "$current_task")
    
    if ! has_changes "$local_changes"; then
        log_message "INFO" "No local changes for task $task_uuid"
        return 0
    fi
    
    log_message "INFO" "Local changes detected: $(echo "$local_changes" | jq -c '.')"
    
    # For now, just queue the push
    # In a full implementation, we'd also check remote changes and resolve conflicts
    queue_change "$task_uuid" "push" "$local_changes"
}

# ============================================================================
# TASKWARRIOR HOOK INTEGRATION
# ============================================================================

on_modify_hook() {
    # This would be called by TaskWarrior's on-modify hook
    # Input: JSON of task before and after modification
    
    local old_task="$1"
    local new_task="$2"
    
    local task_uuid=$(echo "$new_task" | jq -r '.uuid')
    
    # Check if task is synced
    local sync_state=$(get_sync_state "$task_uuid")
    if [[ -n "$sync_state" && "$sync_state" != "null" ]]; then
        # Task is synced - detect and queue changes
        sync_task "$task_uuid" &
    fi
    
    # Return new task (required by TaskWarrior)
    echo "$new_task"
}

# ============================================================================
# CLI COMMANDS
# ============================================================================

cmd_init() {
    init_sync_service
}

cmd_enable() {
    local task_uuid="$1"
    local issue_number="$2"
    
    if [[ -z "$task_uuid" || -z "$issue_number" ]]; then
        echo "Usage: $0 enable <task-uuid> <issue-number>"
        return 1
    fi
    
    log_message "INFO" "Enabling sync for task $task_uuid with GitHub issue #$issue_number"
    
    local task_json=$(get_task_state "$task_uuid")
    local new_state=$(cat <<EOF
{
  "task_uuid": "$task_uuid",
  "service_type": "github",
  "service_id": "$issue_number",
  "last_sync": "$(date -Iseconds)",
  "last_local_state": $task_json,
  "last_remote_state": null,
  "local_checksum": "$(calculate_checksum "$task_json")",
  "remote_checksum": "",
  "sync_enabled": true
}
EOF
)
    
    save_sync_state "$task_uuid" "$new_state"
    echo "Sync enabled for task $task_uuid ↔ GitHub issue #$issue_number"
}

cmd_sync() {
    local task_uuid="$1"
    
    if [[ -z "$task_uuid" ]]; then
        echo "Usage: $0 sync <task-uuid>"
        return 1
    fi
    
    sync_task "$task_uuid"
}

cmd_process() {
    process_queue
}

cmd_status() {
    echo "Two-Way Sync Service Status"
    echo "============================"
    echo ""
    echo "Sync directory: $SYNC_DIR"
    echo "State database: $STATE_DB"
    echo "Strategy: $SYNC_STRATEGY"
    echo ""
    
    local synced_tasks=$(jq 'keys | length' "$STATE_DB")
    echo "Synced tasks: $synced_tasks"
    
    local queued=$(find "$QUEUE_DIR" -name "*.json" 2>/dev/null | wc -l)
    echo "Queued changes: $queued"
    
    local conflicts=$(find "$CONFLICT_DIR" -name "*.json" 2>/dev/null | wc -l)
    echo "Pending conflicts: $conflicts"
}

cmd_conflicts() {
    echo "Pending Conflicts"
    echo "================="
    echo ""
    
    for conflict_file in "$CONFLICT_DIR"/*.json; do
        [[ -f "$conflict_file" ]] || continue
        
        local task_uuid=$(jq -r '.task_uuid' "$conflict_file")
        local timestamp=$(jq -r '.timestamp' "$conflict_file")
        
        echo "Task: $task_uuid"
        echo "Time: $timestamp"
        echo "Local changes: $(jq -c '.local_changes' "$conflict_file")"
        echo "Remote changes: $(jq -c '.remote_changes' "$conflict_file")"
        echo ""
    done
}

cmd_help() {
    cat <<EOF
Two-Way Sync Service - Prototype

Usage: $0 <command> [options]

Commands:
  init                    Initialize sync service
  enable <uuid> <issue>   Enable sync for a task
  sync <uuid>             Sync a specific task
  process                 Process queued changes
  status                  Show sync status
  conflicts               List pending conflicts
  help                    Show this help

Environment Variables:
  SYNC_STRATEGY           Conflict resolution strategy (default: last_write_wins)
  SYNC_INTERVAL           Sync interval in seconds (default: 300)
  DRY_RUN                 Set to 1 for dry-run mode (default: 0)

Examples:
  # Initialize sync service
  $0 init
  
  # Enable sync for a task
  $0 enable abc-123 42
  
  # Sync a task
  $0 sync abc-123
  
  # Process queue
  $0 process
  
  # Dry run
  DRY_RUN=1 $0 sync abc-123

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        init) cmd_init "$@" ;;
        enable) cmd_enable "$@" ;;
        sync) cmd_sync "$@" ;;
        process) cmd_process "$@" ;;
        status) cmd_status "$@" ;;
        conflicts) cmd_conflicts "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            echo "Unknown command: $command"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
