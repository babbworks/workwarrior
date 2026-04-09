#!/usr/bin/env bash
set -euo pipefail
#
# services/profile/urgency.sh
# ww profile urgency <subcommand> — urgency coefficient management
#
# Subcommands:
#   show                     Show current coefficients and active task scores
#   set <factor> <value>     Set a coefficient in .taskrc
#   tune                     Interactive wizard — review and adjust coefficients
#   reset                    Remove all ww-managed urgency coefficients
#   explain <task-id>        Break down urgency score for a specific task
#   help                     Show this help

_URG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_WW_BASE="$(cd "${_URG_DIR}/../.." && pwd)"

# shellcheck source=../../lib/core-utils.sh
source "${_WW_BASE}/lib/core-utils.sh"

# ── Resolve profile ────────────────────────────────────────────────────────────

_resolve_profile() {
    if [[ -n "${WORKWARRIOR_BASE:-}" ]]; then
        PROFILE_BASE="${WORKWARRIOR_BASE}"
        PROFILE_NAME="${WARRIOR_PROFILE:-$(basename "${PROFILE_BASE}")}"
    else
        log_error "No active profile. Activate with: p-<profile-name>"
        exit 1
    fi
    TASKRC_FILE="${PROFILE_BASE}/.taskrc"
    TASKDATA_DIR="${PROFILE_BASE}/.task"
    if [[ ! -f "${TASKRC_FILE}" ]]; then
        log_error ".taskrc not found at ${TASKRC_FILE}"
        exit 1
    fi
}

# ── TW default coefficients ────────────────────────────────────────────────────

# All TW built-in urgency factors and their defaults
declare -A _TW_DEFAULTS=(
    [due]=12.0
    [blocking]=8.0
    [active]=4.0
    [scheduled]=5.0
    [age]=2.0
    [annotations]=1.0
    [tags]=1.0
    [project]=1.0
    [waiting]=-3.0
    [blocked]=-5.0
    [overdue]=12.0
    [priority.H]=6.0
    [priority.M]=3.9
    [priority.L]=-1.8
    [inherit]=0.0
)

# ── Read coefficients from .taskrc ────────────────────────────────────────────

# Output all urgency.*.coefficient lines currently set in .taskrc
_read_coefficients() {
    grep -E '^urgency\.[^=]+=[-0-9.]' "${TASKRC_FILE}" 2>/dev/null \
        | grep '\.coefficient=' || true
}

# Get current coefficient for a factor (falls back to TW default if known)
_get_coefficient() {
    local factor="$1"
    local val
    val=$(grep -E "^urgency\\.${factor}\\.coefficient=" "${TASKRC_FILE}" \
        | cut -d= -f2 | head -1 || true)
    if [[ -n "${val}" ]]; then
        echo "${val}"
    elif [[ -n "${_TW_DEFAULTS[${factor}]+_}" ]]; then
        echo "${_TW_DEFAULTS[${factor}]}"
    else
        echo "0.0"
    fi
}

# ── Read UDA names from .taskrc ───────────────────────────────────────────────

_read_uda_names() {
    grep -E '^uda\.[^.]+\.type=' "${TASKRC_FILE}" \
        | awk -F. '{print $2}' | sort -u || true
}

# ── WW URGENCY block helpers ──────────────────────────────────────────────────

_write_coefficient() {
    local factor="$1"
    local value="$2"
    local taskrc="${TASKRC_FILE}"
    local key="urgency.${factor}.coefficient"

    if grep -q "^# === WW URGENCY ===" "${taskrc}" 2>/dev/null; then
        if grep -q "^${key}=" "${taskrc}" 2>/dev/null; then
            awk -v key="${key}" -v val="${value}" \
                '$0 ~ "^"key"=" { print key"="val; next } { print }' \
                "${taskrc}" > "${taskrc}.tmp" && mv "${taskrc}.tmp" "${taskrc}"
        else
            awk -v line="${key}=${value}" \
                '/^# === END WW URGENCY ===/ { print line } { print }' \
                "${taskrc}" > "${taskrc}.tmp" && mv "${taskrc}.tmp" "${taskrc}"
        fi
    else
        printf '\n# === WW URGENCY ===\n%s=%s\n# === END WW URGENCY ===\n' \
            "${key}" "${value}" >> "${taskrc}"
    fi
}

_remove_all_ww_urgency() {
    local taskrc="${TASKRC_FILE}"
    awk '/^# === WW URGENCY ===/,/^# === END WW URGENCY ===/{next} {print}' \
        "${taskrc}" > "${taskrc}.tmp" && mv "${taskrc}.tmp" "${taskrc}"
}

# ── Validate numeric ──────────────────────────────────────────────────────────

_is_numeric() {
    [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

# ── show subcommand ───────────────────────────────────────────────────────────

cmd_urgency_show() {
    _resolve_profile
    echo ""
    echo "Urgency coefficients — profile '${PROFILE_NAME}'"
    echo ""

    # ── Built-in factors ──
    echo "━━━ Built-in factors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  %-30s %-10s %s\n" "Factor" "Coefficient" "Source"
    printf "  %-30s %-10s %s\n" "──────" "───────────" "──────"

    local builtin_factors=(due blocking active scheduled age annotations tags project waiting blocked overdue "priority.H" "priority.M" "priority.L")
    for factor in "${builtin_factors[@]}"; do
        local coeff source
        coeff=$(grep -E "^urgency\\.${factor}\\.coefficient=" "${TASKRC_FILE}" \
            | cut -d= -f2 | head -1 || true)
        if [[ -n "${coeff}" ]]; then
            source="taskrc"
        else
            coeff="${_TW_DEFAULTS[${factor}]:-0.0}"
            source="default"
        fi
        printf "  %-30s %-10s %s\n" "${factor}" "${coeff}" "${source}"
    done

    # ── UDA presence coefficients ──
    local uda_names
    uda_names=$(_read_uda_names)
    if [[ -n "${uda_names}" ]]; then
        echo ""
        echo "━━━ UDA presence coefficients ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "  %-30s %-10s %s\n" "UDA (any value)" "Coefficient" "Source"
        printf "  %-30s %-10s %s\n" "───────────────" "───────────" "──────"
        while IFS= read -r uda; do
            local coeff source
            coeff=$(grep -E "^urgency\\.uda\\.${uda}\\.coefficient=" "${TASKRC_FILE}" \
                | cut -d= -f2 | head -1 || true)
            if [[ -n "${coeff}" ]]; then
                source="taskrc"
            else
                coeff="0.0"
                source="default"
            fi
            printf "  %-30s %-10s %s\n" "uda.${uda}" "${coeff}" "${source}"
        done <<< "${uda_names}"
    fi

    # ── UDA value coefficients ──
    local value_coeffs
    value_coeffs=$(grep -E '^urgency\.uda\.[^.]+\.[^.]+\.coefficient=' "${TASKRC_FILE}" 2>/dev/null || true)
    if [[ -n "${value_coeffs}" ]]; then
        echo ""
        echo "━━━ UDA value coefficients ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "  %-30s %s\n" "Factor" "Coefficient"
        printf "  %-30s %s\n" "──────" "───────────"
        while IFS= read -r line; do
            local factor coeff
            factor="${line%%=*}"
            factor="${factor#urgency.}"
            coeff="${line##*=}"
            printf "  %-30s %s\n" "${factor}" "${coeff}"
        done <<< "${value_coeffs}"
    fi

    echo ""

    # ── Active task scores (top 10) ──
    local task_count
    task_count=$(TASKRC="${TASKRC_FILE}" TASKDATA="${TASKDATA_DIR}" \
        task status:pending count 2>/dev/null || echo "0")
    if [[ "${task_count}" -gt 0 ]]; then
        echo "━━━ Top tasks by urgency ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        TASKRC="${TASKRC_FILE}" TASKDATA="${TASKDATA_DIR}" \
            task rc.verbose=nothing status:pending \
            limit:10 _urgency 2>/dev/null \
            | awk '{printf "  %6.2f  %s\n", $1, $2}' \
            | sort -rn | head -10 || true
        echo ""
    fi
}

# ── set subcommand ────────────────────────────────────────────────────────────

cmd_urgency_set() {
    local factor="${1:-}"
    local value="${2:-}"
    _resolve_profile

    if [[ -z "${factor}" || -z "${value}" ]]; then
        log_error "Usage: ww profile urgency set <factor> <value>"
        echo "" >&2
        echo "  Examples:" >&2
        echo "    ww profile urgency set due 10.0" >&2
        echo "    ww profile urgency set uda.phase.review 5.0" >&2
        echo "    ww profile urgency set uda.goals 2.0" >&2
        exit 1
    fi

    if ! _is_numeric "${value}"; then
        log_error "Value must be numeric (got: '${value}')"
        exit 1
    fi

    _write_coefficient "${factor}" "${value}"
    echo "✓ urgency.${factor}.coefficient=${value}"
}

# ── tune subcommand ───────────────────────────────────────────────────────────

cmd_urgency_tune() {
    _resolve_profile
    echo ""
    echo "Urgency Tuning Wizard — profile '${PROFILE_NAME}'"
    echo "Press Enter to keep current value, or type a new number."
    echo ""

    declare -A pending_changes

    # ── Built-in factors ──
    echo "━━━ Built-in factors ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local key_factors=(due blocking active scheduled age waiting blocked "priority.H" "priority.M" "priority.L")
    for factor in "${key_factors[@]}"; do
        local current
        current=$(_get_coefficient "${factor}")
        read -rp "  ${factor} [${current}]: " input
        if [[ -n "${input}" ]]; then
            if ! _is_numeric "${input}"; then
                echo "  ! Not numeric, skipping '${factor}'" >&2
                continue
            fi
            pending_changes["${factor}"]="${input}"
        fi
    done

    # ── UDA presence coefficients ──
    local uda_names
    uda_names=$(_read_uda_names)
    if [[ -n "${uda_names}" ]]; then
        echo ""
        echo "━━━ UDA presence (any value set adds this weight) ━━━━━━━━━━━━━━━━━━━━"
        while IFS= read -r uda; do
            local current
            current=$(_get_coefficient "uda.${uda}")
            read -rp "  uda.${uda} [${current}]: " input
            if [[ -n "${input}" ]]; then
                if ! _is_numeric "${input}"; then
                    echo "  ! Not numeric, skipping 'uda.${uda}'" >&2
                    continue
                fi
                pending_changes["uda.${uda}"]="${input}"
            fi
        done <<< "${uda_names}"
    fi

    # ── Confirm and apply ──
    if [[ "${#pending_changes[@]}" -eq 0 ]]; then
        echo ""
        echo "No changes made."
        return 0
    fi

    echo ""
    echo "━━━ Pending changes ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for factor in "${!pending_changes[@]}"; do
        local old new
        old=$(_get_coefficient "${factor}")
        new="${pending_changes[${factor}]}"
        printf "  %-30s %s → %s\n" "${factor}" "${old}" "${new}"
    done
    echo ""
    read -rp "Apply these changes? [y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && echo "Aborted." && return 0

    for factor in "${!pending_changes[@]}"; do
        _write_coefficient "${factor}" "${pending_changes[${factor}]}"
    done
    echo "✓ ${#pending_changes[@]} coefficient(s) updated."
}

# ── reset subcommand ──────────────────────────────────────────────────────────

cmd_urgency_reset() {
    _resolve_profile
    local count
    count=$(grep -c '^urgency\.' "${TASKRC_FILE}" 2>/dev/null || true)

    if [[ "${count}" -eq 0 ]]; then
        echo "No urgency coefficients set in profile '${PROFILE_NAME}'."
        return 0
    fi

    echo "This will remove all urgency coefficients from profile '${PROFILE_NAME}'."
    echo "TaskWarrior defaults will apply (due=12.0, blocking=8.0, etc.)"
    read -rp "Continue? [y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && echo "Aborted." && return 0

    _remove_all_ww_urgency

    # Also remove any urgency lines outside the WW block
    awk '/^urgency\..*\.coefficient=/{next} {print}' \
        "${TASKRC_FILE}" > "${TASKRC_FILE}.tmp" && mv "${TASKRC_FILE}.tmp" "${TASKRC_FILE}"

    echo "✓ All urgency coefficients removed. TW defaults restored."
}

# ── explain subcommand ────────────────────────────────────────────────────────

cmd_urgency_explain() {
    local task_id="${1:-}"
    _resolve_profile

    if [[ -z "${task_id}" ]]; then
        log_error "Usage: ww profile urgency explain <task-id>"
        exit 1
    fi

    # Verify task exists
    local task_json
    task_json=$(TASKRC="${TASKRC_FILE}" TASKDATA="${TASKDATA_DIR}" \
        task "${task_id}" export 2>/dev/null || true)
    if [[ -z "${task_json}" ]] || ! echo "${task_json}" | grep -q '"uuid"'; then
        log_error "Task '${task_id}' not found in profile '${PROFILE_NAME}'."
        exit 1
    fi

    local task_desc
    task_desc=$(echo "${task_json}" | grep -o '"description":"[^"]*"' \
        | cut -d'"' -f4 | head -1 || echo "task ${task_id}")

    echo ""
    echo "Urgency breakdown — ${task_id}: ${task_desc}"
    echo ""

    local total=0

    # ── Built-in factors ──
    local due_date status priority tags project blocking blocked active scheduled

    due_date=$(echo "${task_json}"   | grep -o '"due":"[^"]*"'      | cut -d'"' -f4 || true)
    status=$(echo "${task_json}"     | grep -o '"status":"[^"]*"'   | cut -d'"' -f4 || true)
    priority=$(echo "${task_json}"   | grep -o '"priority":"[^"]*"' | cut -d'"' -f4 || true)
    project=$(echo "${task_json}"    | grep -o '"project":"[^"]*"'  | cut -d'"' -f4 || true)

    printf "  %-32s %s\n" "Factor" "Contribution"
    printf "  %-32s %s\n" "──────" "────────────"

    # Due date contribution
    if [[ -n "${due_date}" ]]; then
        local due_coeff days_until contrib
        due_coeff=$(_get_coefficient "due")
        # days until due (approximate — TW's actual formula is more complex)
        local now_ts due_ts
        now_ts=$(date +%s)
        due_ts=$(date -j -f "%Y%m%dT%H%M%SZ" "${due_date}" +%s 2>/dev/null \
            || date -d "${due_date}" +%s 2>/dev/null || echo "${now_ts}")
        days_until=$(( (due_ts - now_ts) / 86400 ))
        # TW uses a normalized scale: contrib ≈ coeff * (1 - days/14) clamped to [-1,1]
        # Simplified display: show coefficient and days
        if [[ "${days_until}" -lt 0 ]]; then
            local overdue_coeff
            overdue_coeff=$(_get_coefficient "overdue")
            printf "  %-32s +%s  (overdue by %d days)\n" "due (overdue)" "${overdue_coeff}" $(( -days_until ))
        else
            printf "  %-32s +%s  (due in %d days)\n" "due" "${due_coeff}" "${days_until}"
        fi
    fi

    # Active
    if echo "${task_json}" | grep -q '"start":'; then
        local c; c=$(_get_coefficient "active")
        printf "  %-32s +%s\n" "active" "${c}"
    fi

    # Priority
    if [[ -n "${priority}" ]]; then
        local pkey c
        pkey="priority.${priority}"
        c=$(_get_coefficient "${pkey}")
        printf "  %-32s +%s\n" "priority=${priority}" "${c}"
    fi

    # Project
    if [[ -n "${project}" ]]; then
        local c; c=$(_get_coefficient "project")
        printf "  %-32s +%s  (project: ${project})\n" "project" "${c}"
    fi

    # Blocked / blocking (from depends field)
    if echo "${task_json}" | grep -q '"depends":'; then
        local c; c=$(_get_coefficient "blocked")
        printf "  %-32s %s\n" "blocked" "${c}"
    fi

    # ── UDA presence coefficients ──
    local uda_names
    uda_names=$(_read_uda_names)
    if [[ -n "${uda_names}" ]]; then
        while IFS= read -r uda; do
            local uda_val coeff
            uda_val=$(echo "${task_json}" | grep -o "\"${uda}\":\"[^\"]*\"" \
                | cut -d'"' -f4 | head -1 || true)
            if [[ -n "${uda_val}" ]]; then
                coeff=$(grep -E "^urgency\\.uda\\.${uda}\\.coefficient=" "${TASKRC_FILE}" \
                    | cut -d= -f2 | head -1 || true)
                if [[ -n "${coeff}" && "${coeff}" != "0.0" && "${coeff}" != "0" ]]; then
                    printf "  %-32s +%s  (%s=%s)\n" "uda.${uda} (present)" "${coeff}" "${uda}" "${uda_val}"
                fi

                # Per-value coefficient
                local val_coeff
                val_coeff=$(grep -E "^urgency\\.uda\\.${uda}\\.${uda_val}\\.coefficient=" \
                    "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
                if [[ -n "${val_coeff}" && "${val_coeff}" != "0.0" ]]; then
                    printf "  %-32s +%s\n" "uda.${uda}=${uda_val}" "${val_coeff}"
                fi
            fi
        done <<< "${uda_names}"
    fi

    # ── Total from TW directly ──
    local tw_urgency
    tw_urgency=$(TASKRC="${TASKRC_FILE}" TASKDATA="${TASKDATA_DIR}" \
        task "${task_id}" _urgency 2>/dev/null | head -1 || echo "n/a")

    echo ""
    printf "  %-32s %s\n" "─────────────────────────────" "────────────"
    printf "  %-32s %s  (calculated by TaskWarrior)\n" "Total urgency" "${tw_urgency}"
    echo ""
}

# ── help ──────────────────────────────────────────────────────────────────────

show_urgency_help() {
    cat << 'EOF'
Urgency Coefficient Management

Usage: ww profile urgency <subcommand> [arguments]

Subcommands:
  show                     Show all coefficients and top task urgency scores
  set <factor> <value>     Set a single coefficient
  tune                     Interactive wizard — step through all factors
  reset                    Remove all ww-managed coefficients (restore defaults)
  explain <task-id>        Break down urgency score for one task
  help                     Show this help

How urgency works:
  urgency = Σ (coefficient × factor_value)

  Built-in factors (TW defaults):
    due=12.0  blocking=8.0  scheduled=5.0  active=4.0  age=2.0
    waiting=-3.0  blocked=-5.0  priority.H=6.0  priority.M=3.9

  UDA coefficients (default 0.0 unless set):
    urgency.uda.<name>.coefficient         — adds weight when any value is set
    urgency.uda.<name>.<value>.coefficient — adds weight for a specific value

Examples:
  ww profile urgency show
  ww profile urgency set due 10.0
  ww profile urgency set uda.phase.review 5.0
  ww profile urgency set uda.goals 2.0
  ww profile urgency tune
  ww profile urgency explain 42
  ww profile urgency reset

See: https://taskwarrior.org/docs/urgency/
EOF
}

# ── dispatch ──────────────────────────────────────────────────────────────────

main() {
    local subcommand="${1:-show}"
    shift || true

    case "${subcommand}" in
        show)           cmd_urgency_show "$@" ;;
        set)            cmd_urgency_set "$@" ;;
        tune)           cmd_urgency_tune "$@" ;;
        reset)          cmd_urgency_reset "$@" ;;
        explain)        cmd_urgency_explain "$@" ;;
        help|-h|--help) show_urgency_help ;;
        *)
            log_error "Unknown urgency subcommand: ${subcommand}"
            show_urgency_help
            exit 1 ;;
    esac
}

main "$@"
