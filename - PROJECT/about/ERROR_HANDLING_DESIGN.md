# Error Handling Design: Interactive Field Correction

## Overview

When sync operations fail due to field validation errors, we provide an interactive script that guides the user through correcting each problematic field with clear context and error information.

## Error Handling Flow

```
Sync Operation Fails
        ↓
Capture Error Details
        ↓
Parse Error by Field
        ↓
For Each Problematic Field:
    ├─ Show current value
    ├─ Show error message
    ├─ Show expected format
    ├─ Show server response
    ├─ Prompt for correction
    └─ Validate new value
        ↓
Retry Sync with Corrections
        ↓
Success or Repeat
```

## Error Categories

### 1. Validation Errors
```bash
# GitHub API validation failures
- Title too long (>256 chars)
- Invalid label format
- Invalid state value
- Invalid milestone reference
- Invalid assignee username
```

### 2. Permission Errors
```bash
# GitHub API permission failures
- No write access to repository
- Cannot assign users (not collaborator)
- Cannot create labels (no permission)
- Cannot modify milestone (no permission)
```

### 3. Rate Limit Errors
```bash
# GitHub API rate limiting
- Primary rate limit exceeded
- Secondary rate limit exceeded
- Abuse detection triggered
```

### 4. Network Errors
```bash
# Connection failures
- Timeout
- Connection refused
- DNS resolution failure
- SSL certificate error
```

### 5. Data Conflicts
```bash
# Sync conflicts
- Issue modified since last sync
- Task modified since last sync
- Both modified (conflict)
```

## Interactive Error Correction Script

### Script: `lib/error-handler.sh`

```bash
#!/usr/bin/env bash
# Interactive error correction for sync failures

# ============================================================================
# ERROR PARSING
# ============================================================================

parse_github_error() {
    local error_response="$1"
    
    # Extract error details from GitHub API response
    local error_message=$(echo "$error_response" | jq -r '.message // .error')
    local error_field=$(echo "$error_response" | jq -r '.errors[0].field // ""')
    local error_code=$(echo "$error_response" | jq -r '.errors[0].code // ""')
    local error_value=$(echo "$error_response" | jq -r '.errors[0].value // ""')
    
    echo "$error_field|$error_code|$error_message|$error_value"
}

categorize_error() {
    local error_code="$1"
    
    case "$error_code" in
        invalid|too_long|missing_field)
            echo "validation"
            ;;
        forbidden|unauthorized)
            echo "permission"
            ;;
        rate_limit|abuse)
            echo "rate_limit"
            ;;
        timeout|connection_failed)
            echo "network"
            ;;
        conflict|stale)
            echo "conflict"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ============================================================================
# FIELD-SPECIFIC ERROR HANDLERS
# ============================================================================

handle_title_error() {
    local task_uuid="$1"
    local current_value="$2"
    local error_message="$3"
    local error_details="$4"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Error: Issue Title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Task UUID: $task_uuid"
    echo ""
    echo "Current Value:"
    echo "  \"$current_value\""
    echo ""
    echo "Error:"
    echo "  $error_message"
    echo ""
    echo "Details:"
    echo "  $error_details"
    echo ""
    echo "Requirements:"
    echo "  - Maximum length: 256 characters"
    echo "  - Current length: ${#current_value} characters"
    echo "  - Must not be empty"
    echo ""
    
    # Suggest truncation if too long
    if [[ ${#current_value} -gt 256 ]]; then
        local truncated="${current_value:0:253}..."
        echo "Suggested Fix (truncated):"
        echo "  \"$truncated\""
        echo ""
    fi
    
    # Prompt for correction
    while true; do
        read -p "Enter corrected title (or 'skip' to skip this sync): " new_value
        
        if [[ "$new_value" == "skip" ]]; then
            return 1
        fi
        
        # Validate new value
        if [[ -z "$new_value" ]]; then
            echo "❌ Error: Title cannot be empty"
            continue
        fi
        
        if [[ ${#new_value} -gt 256 ]]; then
            echo "❌ Error: Title too long (${#new_value} chars, max 256)"
            continue
        fi
        
        # Update task
        task "$task_uuid" modify description:"$new_value"
        echo "✅ Title updated in TaskWarrior"
        return 0
    done
}

handle_state_error() {
    local task_uuid="$1"
    local current_value="$2"
    local error_message="$3"
    local error_details="$4"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Error: Issue State"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Task UUID: $task_uuid"
    echo ""
    echo "Current Value:"
    echo "  TaskWarrior status: $current_value"
    echo ""
    echo "Error:"
    echo "  $error_message"
    echo ""
    echo "Details:"
    echo "  $error_details"
    echo ""
    echo "Valid States:"
    echo "  1. OPEN   (pending, started, waiting)"
    echo "  2. CLOSED (completed, deleted)"
    echo ""
    
    # Prompt for correction
    while true; do
        read -p "Select state [1=OPEN, 2=CLOSED, skip]: " choice
        
        case "$choice" in
            1)
                task "$task_uuid" modify status:pending
                echo "✅ Status updated to: pending (OPEN)"
                return 0
                ;;
            2)
                task "$task_uuid" modify status:completed
                echo "✅ Status updated to: completed (CLOSED)"
                return 0
                ;;
            skip)
                return 1
                ;;
            *)
                echo "❌ Invalid choice"
                ;;
        esac
    done
}

handle_label_error() {
    local task_uuid="$1"
    local current_value="$2"
    local error_message="$3"
    local error_details="$4"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Error: Labels/Tags"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Task UUID: $task_uuid"
    echo ""
    echo "Current Tags:"
    echo "  $current_value"
    echo ""
    echo "Error:"
    echo "  $error_message"
    echo ""
    echo "Details:"
    echo "  $error_details"
    echo ""
    echo "Requirements:"
    echo "  - Label names: alphanumeric, hyphens, underscores"
    echo "  - Maximum length: 50 characters per label"
    echo "  - No spaces (use hyphens instead)"
    echo ""
    
    # Parse problematic tag
    local bad_tag=$(echo "$error_details" | grep -oP 'tag: \K[^ ]+' || echo "")
    
    if [[ -n "$bad_tag" ]]; then
        echo "Problematic Tag:"
        echo "  \"$bad_tag\""
        echo ""
        
        # Suggest fix
        local fixed_tag=$(echo "$bad_tag" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        echo "Suggested Fix:"
        echo "  \"$fixed_tag\""
        echo ""
    fi
    
    # Prompt for correction
    while true; do
        echo "Options:"
        echo "  1. Remove problematic tag"
        echo "  2. Replace with suggested fix"
        echo "  3. Enter new tag"
        echo "  4. Skip this sync"
        echo ""
        read -p "Choose option [1-4]: " choice
        
        case "$choice" in
            1)
                task "$task_uuid" modify -"$bad_tag"
                echo "✅ Tag removed: $bad_tag"
                return 0
                ;;
            2)
                task "$task_uuid" modify -"$bad_tag" +"$fixed_tag"
                echo "✅ Tag replaced: $bad_tag → $fixed_tag"
                return 0
                ;;
            3)
                read -p "Enter new tag: " new_tag
                if [[ -n "$new_tag" ]]; then
                    task "$task_uuid" modify -"$bad_tag" +"$new_tag"
                    echo "✅ Tag replaced: $bad_tag → $new_tag"
                    return 0
                fi
                ;;
            4|skip)
                return 1
                ;;
            *)
                echo "❌ Invalid choice"
                ;;
        esac
    done
}

handle_permission_error() {
    local task_uuid="$1"
    local operation="$2"
    local error_message="$3"
    local error_details="$4"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Error: Permission Denied"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Task UUID: $task_uuid"
    echo "Operation: $operation"
    echo ""
    echo "Error:"
    echo "  $error_message"
    echo ""
    echo "Details:"
    echo "  $error_details"
    echo ""
    echo "Possible Causes:"
    echo "  - No write access to repository"
    echo "  - GitHub token lacks required permissions"
    echo "  - Repository is archived or read-only"
    echo ""
    echo "Solutions:"
    echo "  1. Check repository permissions"
    echo "  2. Verify GitHub token scopes (needs 'repo' scope)"
    echo "  3. Run: gh auth refresh -s repo"
    echo ""
    
    read -p "Press Enter to continue..."
    return 1
}

handle_rate_limit_error() {
    local error_response="$1"
    
    # Extract rate limit info
    local limit=$(echo "$error_response" | jq -r '.rate.limit // 5000')
    local remaining=$(echo "$error_response" | jq -r '.rate.remaining // 0')
    local reset=$(echo "$error_response" | jq -r '.rate.reset // 0')
    
    # Calculate wait time
    local now=$(date +%s)
    local wait_seconds=$((reset - now))
    local wait_minutes=$((wait_seconds / 60))
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Error: GitHub Rate Limit Exceeded"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Rate Limit Info:"
    echo "  Limit:     $limit requests/hour"
    echo "  Remaining: $remaining requests"
    echo "  Resets in: $wait_minutes minutes"
    echo ""
    echo "Options:"
    echo "  1. Wait for rate limit reset"
    echo "  2. Skip this sync"
    echo "  3. Continue anyway (may fail)"
    echo ""
    
    read -p "Choose option [1-3]: " choice
    
    case "$choice" in
        1)
            echo "Waiting for rate limit reset..."
            sleep "$wait_seconds"
            return 0
            ;;
        2)
            return 1
            ;;
        3)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# MAIN ERROR HANDLER
# ============================================================================

handle_sync_error() {
    local task_uuid="$1"
    local operation="$2"  # push or pull
    local error_response="$3"
    
    # Parse error
    local error_info=$(parse_github_error "$error_response")
    IFS='|' read -r error_field error_code error_message error_value <<< "$error_info"
    
    # Categorize error
    local error_category=$(categorize_error "$error_code")
    
    # Log error
    log_error "Sync failed for task $task_uuid: $error_message"
    
    # Handle by category
    case "$error_category" in
        validation)
            # Handle field-specific validation errors
            case "$error_field" in
                title)
                    handle_title_error "$task_uuid" "$error_value" "$error_message" "$error_response"
                    ;;
                state)
                    handle_state_error "$task_uuid" "$error_value" "$error_message" "$error_response"
                    ;;
                labels)
                    handle_label_error "$task_uuid" "$error_value" "$error_message" "$error_response"
                    ;;
                *)
                    handle_generic_validation_error "$task_uuid" "$error_field" "$error_value" "$error_message"
                    ;;
            esac
            ;;
            
        permission)
            handle_permission_error "$task_uuid" "$operation" "$error_message" "$error_response"
            ;;
            
        rate_limit)
            handle_rate_limit_error "$error_response"
            ;;
            
        network)
            handle_network_error "$task_uuid" "$operation" "$error_message"
            ;;
            
        conflict)
            handle_conflict_error "$task_uuid" "$error_response"
            ;;
            
        *)
            handle_unknown_error "$task_uuid" "$operation" "$error_response"
            ;;
    esac
    
    return $?
}

# ============================================================================
# RETRY LOGIC
# ============================================================================

sync_with_error_handling() {
    local task_uuid="$1"
    local operation="$2"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        # Attempt sync
        local error_response
        if error_response=$(perform_sync "$task_uuid" "$operation" 2>&1); then
            echo "✅ Sync successful"
            return 0
        fi
        
        # Sync failed - handle error
        echo "❌ Sync failed (attempt $((retry_count + 1))/$max_retries)"
        
        if ! handle_sync_error "$task_uuid" "$operation" "$error_response"; then
            # User chose to skip
            echo "Skipping sync for task $task_uuid"
            return 1
        fi
        
        # User corrected the issue - retry
        ((retry_count++))
        echo "Retrying sync..."
    done
    
    echo "❌ Sync failed after $max_retries attempts"
    return 1
}

# ============================================================================
# BATCH ERROR HANDLING
# ============================================================================

handle_batch_errors() {
    local failed_tasks=("$@")
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Batch Sync Errors"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Failed to sync ${#failed_tasks[@]} task(s)"
    echo ""
    echo "Options:"
    echo "  1. Fix errors interactively (one by one)"
    echo "  2. View error log"
    echo "  3. Skip all failed tasks"
    echo ""
    
    read -p "Choose option [1-3]: " choice
    
    case "$choice" in
        1)
            for task_uuid in "${failed_tasks[@]}"; do
                echo ""
                echo "Processing task: $task_uuid"
                sync_with_error_handling "$task_uuid" "push"
            done
            ;;
        2)
            cat "$ERROR_LOG_FILE"
            ;;
        3)
            echo "Skipped ${#failed_tasks[@]} task(s)"
            ;;
    esac
}
```

## Error Log Format

### Log File: `~/.task/github-sync/errors.log`

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "task_uuid": "abc-123",
  "operation": "push",
  "error_category": "validation",
  "error_field": "title",
  "error_code": "too_long",
  "error_message": "Title is too long (300 characters, max 256)",
  "current_value": "Very long title...",
  "github_response": {...},
  "resolved": false,
  "resolution": null
}
```

## User Experience Flow

### Example: Title Too Long

```
❌ Sync failed for task abc-123

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Error: Issue Title
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task UUID: abc-123

Current Value:
  "Implement comprehensive user authentication system with OAuth2, JWT tokens, and multi-factor authentication support including SMS and authenticator apps with fallback to email verification and password reset functionality"

Error:
  Title is too long

Details:
  Maximum length: 256 characters
  Current length: 300 characters

Requirements:
  - Maximum length: 256 characters
  - Current length: 300 characters
  - Must not be empty

Suggested Fix (truncated):
  "Implement comprehensive user authentication system with OAuth2, JWT tokens, and multi-factor authentication support including SMS and authenticator apps with fallback to email verification and password reset..."

Enter corrected title (or 'skip' to skip this sync): Implement user auth with OAuth2, JWT, and MFA

✅ Title updated in TaskWarrior
Retrying sync...
✅ Sync successful
```

## Summary

This error handling design provides:

1. **Field-Specific Handlers**: Tailored prompts for each field type
2. **Clear Context**: Shows current value, error, and requirements
3. **Helpful Suggestions**: Offers fixes when possible
4. **Interactive Correction**: Guides user through fixing each issue
5. **Retry Logic**: Automatically retries after correction
6. **Batch Handling**: Processes multiple errors efficiently
7. **Comprehensive Logging**: Tracks all errors for debugging

**Ready to proceed with implementation?**
