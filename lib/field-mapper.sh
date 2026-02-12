#!/usr/bin/env bash
# Field Mapper
# Transforms data between TaskWarrior and GitHub formats

# System tags to exclude from syncing
SYSTEM_TAGS="ACTIVE READY PENDING COMPLETED DELETED WAITING RECURRING PARENT CHILD BLOCKED UNBLOCKED OVERDUE TODAY TOMORROW WEEK MONTH YEAR"

# Map TaskWarrior status to GitHub state
# Input: status (pending|started|waiting|completed|deleted|recurring)
# Output: state (OPEN|CLOSED) to stdout
# Returns: 0 on success
map_status_to_github() {
    local status="$1"
    
    case "${status}" in
        pending|started|waiting|recurring)
            echo "OPEN"
            ;;
        completed|deleted)
            echo "CLOSED"
            ;;
        *)
            echo "Error: Unknown status '${status}'" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Map GitHub state to TaskWarrior status
# Input: state (OPEN|CLOSED), stateReason (optional)
# Output: status (pending|completed|deleted) to stdout
# Returns: 0 on success
map_github_to_status() {
    local state="$1"
    local state_reason="$2"
    
    case "${state}" in
        OPEN|open)
            # Default to pending for OPEN issues
            # Note: We preserve task.start if it exists (handled by caller)
            echo "pending"
            ;;
        CLOSED|closed)
            # Check stateReason to distinguish completed vs deleted
            if [[ "${state_reason}" == "NOT_PLANNED" ]]; then
                echo "deleted"
            else
                echo "completed"
            fi
            ;;
        *)
            echo "Error: Unknown state '${state}'" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Map TaskWarrior priority to GitHub label
# Input: priority (H|M|L|"")
# Output: label (priority:high|priority:medium|priority:low|"") to stdout
# Returns: 0 on success
map_priority_to_label() {
    local priority="$1"
    
    case "${priority}" in
        H)
            echo "priority:high"
            ;;
        M)
            echo "priority:medium"
            ;;
        L)
            echo "priority:low"
            ;;
        "")
            # Empty priority - no label
            echo ""
            ;;
        *)
            echo "Error: Unknown priority '${priority}'" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Map GitHub labels to TaskWarrior priority
# Input: labels (JSON array of label names)
# Output: priority (H|M|L|"") to stdout
# Returns: 0 on success
map_labels_to_priority() {
    local labels="$1"
    
    # Search for priority:* labels (case-insensitive)
    local priority_label
    priority_label=$(echo "${labels}" | jq -r '.[] | select(test("^priority:"; "i"))' | head -1)
    
    if [[ -z "${priority_label}" ]]; then
        # No priority label found
        echo ""
        return 0
    fi
    
    # Extract priority level (case-insensitive)
    case "${priority_label,,}" in
        *high*)
            echo "H"
            ;;
        *medium*)
            echo "M"
            ;;
        *low*)
            echo "L"
            ;;
        *)
            # Unknown priority label format
            echo ""
            ;;
    esac
    
    return 0
}

# Filter system tags
# Input: tags (JSON array)
# Output: filtered tags (JSON array) to stdout
# Returns: 0 on success
filter_system_tags() {
    local tags="$1"
    
    # Build jq filter to exclude system tags and sync:* tags
    local filter='['
    for tag in ${SYSTEM_TAGS}; do
        filter+=". | select(. != \"${tag}\") | "
    done
    # Also exclude sync:* tags
    filter+='select(test("^sync:") | not)]'
    
    echo "${tags}" | jq -c "${filter}"
    return 0
}

# Sanitize label name for GitHub
# Input: name (string)
# Output: sanitized name to stdout
# Returns: 0 on success
sanitize_label_name() {
    local name="$1"
    
    # GitHub label rules:
    # - Alphanumeric, hyphens, underscores
    # - No spaces (convert to hyphens)
    # - Max 50 chars
    
    # Convert spaces to hyphens
    name="${name// /-}"
    
    # Remove invalid characters (keep alphanumeric, hyphens, underscores, colons)
    name=$(echo "${name}" | sed 's/[^a-zA-Z0-9_:-]//g')
    
    # Truncate to 50 chars
    if [[ ${#name} -gt 50 ]]; then
        name="${name:0:50}"
    fi
    
    echo "${name}"
    return 0
}

# Map TaskWarrior tags to GitHub labels
# Input: tags (JSON array)
# Output: labels (comma-separated string) to stdout
# Returns: 0 on success
map_tags_to_labels() {
    local tags="$1"
    
    # Filter out system tags
    local filtered_tags
    filtered_tags=$(filter_system_tags "${tags}")
    
    # Sanitize each tag and convert to comma-separated string
    local labels=""
    while IFS= read -r tag; do
        if [[ -n "${tag}" ]]; then
            local sanitized
            sanitized=$(sanitize_label_name "${tag}")
            if [[ -n "${labels}" ]]; then
                labels="${labels},${sanitized}"
            else
                labels="${sanitized}"
            fi
        fi
    done < <(echo "${filtered_tags}" | jq -r '.[]')
    
    echo "${labels}"
    return 0
}

# Map GitHub labels to TaskWarrior tags
# Input: labels (JSON array of label names)
# Output: tags (JSON array) to stdout
# Returns: 0 on success
map_labels_to_tags() {
    local labels="$1"
    
    # Filter out priority:* labels and sync:* labels
    local filtered_labels
    filtered_labels=$(echo "${labels}" | jq -c '[.[] | select(test("^priority:"; "i") | not) | select(test("^sync:") | not)]')
    
    # Convert to lowercase for consistency
    echo "${filtered_labels}" | jq -c '[.[] | ascii_downcase]'
    return 0
}

# Truncate title if too long
# Input: title (string), max_length (integer, default 256)
# Output: truncated title to stdout
# Returns: 0 on success, 1 if truncated (with warning)
truncate_title() {
    local title="$1"
    local max_length="${2:-256}"
    
    if [[ ${#title} -le ${max_length} ]]; then
        echo "${title}"
        return 0
    fi
    
    # Truncate to max_length - 3 and add "..."
    local truncated="${title:0:$((max_length - 3))}..."
    echo "${truncated}"
    
    echo "Warning: Title truncated from ${#title} to ${max_length} characters" >&2
    return 1
}

# Add TaskWarrior prefix to annotation for GitHub comment
# Input: annotation_text (string)
# Output: prefixed comment text to stdout
# Returns: 0 on success
add_taskwarrior_prefix() {
    local annotation_text="$1"
    
    echo "[TaskWarrior] ${annotation_text}"
    return 0
}

# Add GitHub prefix to comment for TaskWarrior annotation
# Input: comment_text (string), author_username (string)
# Output: prefixed annotation text to stdout
# Returns: 0 on success
add_github_prefix() {
    local comment_text="$1"
    local author_username="$2"
    
    echo "[GitHub @${author_username}] ${comment_text}"
    return 0
}

# Format timestamp for display
# Input: iso8601_timestamp (string)
# Output: formatted timestamp to stdout
# Returns: 0 on success
format_timestamp() {
    local timestamp="$1"
    
    # Convert ISO 8601 to human-readable format
    # macOS date command syntax
    if date -j -f "%Y-%m-%dT%H:%M:%SZ" "${timestamp}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null; then
        return 0
    else
        # Fallback: just echo the original
        echo "${timestamp}"
        return 0
    fi
}

# Get all priority labels from a label list
# Input: labels (JSON array of label names)
# Output: comma-separated priority labels to stdout
# Returns: 0 on success
get_priority_labels() {
    local labels="$1"
    
    # Find all priority:* labels
    local priority_labels
    priority_labels=$(echo "${labels}" | jq -r '.[] | select(test("^priority:"; "i"))' | tr '\n' ',' | sed 's/,$//')
    
    echo "${priority_labels}"
    return 0
}
