#!/usr/bin/env bash
set -euo pipefail
#
# services/profile/subservices/profile-uda.sh
# ww profile uda <subcommand> — full UDA management surface
#
# Subcommands:
#   list [--all]            List UDAs for the active profile
#   add [<name>]            Add a new UDA (interactive wizard)
#   remove <name>           Remove a UDA
#   group <name> [group]    Assign UDA to a group (interactive if group omitted)
#   perm <name> [tokens]    Show or set sync permissions for a UDA
#   help                    Show this help

_UDA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_WW_BASE="$(cd "${_UDA_DIR}/../../.." && pwd)"

# shellcheck source=../../../lib/core-utils.sh
source "${_WW_BASE}/lib/core-utils.sh"
# shellcheck source=../../../lib/sync-permissions.sh
source "${_WW_BASE}/lib/sync-permissions.sh"

REGISTRY="${_WW_BASE}/system/config/service-uda-registry.yaml"
INDICATOR_MAP="${_WW_BASE}/system/config/uda-indicator-map.yaml"
COLOR_MAP="${_WW_BASE}/system/config/uda-color-map.yaml"

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
    if [[ ! -f "${TASKRC_FILE}" ]]; then
        log_error ".taskrc not found at ${TASKRC_FILE}"
        exit 1
    fi
}

# ── Service UDA helpers ────────────────────────────────────────────────────────

# Returns true if a UDA name is service-managed (matches registry prefix or name)
_is_service_uda() {
    local name="$1"
    case "${name}" in
        github_*|gitlab_*|jira_*|trello_*|bw_*|sync_id|sync_repo|sync_state|sync_last|sync_url)
            return 0 ;;
        density|densitywindow)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Returns service name for a UDA, or empty string
_uda_service() {
    local name="$1"
    case "${name}" in
        github_*)  echo "bugwarrior[github]" ;;
        gitlab_*)  echo "bugwarrior[gitlab]" ;;
        jira_*)    echo "bugwarrior[jira]" ;;
        trello_*)  echo "bugwarrior[trello]" ;;
        bw_*)      echo "bugwarrior" ;;
        sync_*)    echo "github-sync" ;;
        density|densitywindow) echo "extension:twdensity" ;;
        *)         echo "" ;;
    esac
}

# ── Read UDA groups from .taskrc ───────────────────────────────────────────────

# Output: "group_name uda1,uda2,uda3" per line
_read_groups() {
    local taskrc="${TASKRC_FILE}"
    sed -n '/^# === WW UDA GROUPS ===/,/^# === END WW UDA GROUPS ===/p' "${taskrc}" \
    | grep '^# group:' \
    | sed 's/^# group://' \
    | awk '{
        # group:work udas:goals,phase description:"..." tags:...
        name=$1
        udas=""
        for(i=2;i<=NF;i++) {
            if($i ~ /^udas:/) { udas=substr($i,6) }
        }
        if(name != "" && udas != "") print name, udas
    }' || true
}

# Get group names that contain a UDA
_groups_for_uda() {
    local uda_name="$1"
    _read_groups | while IFS=' ' read -r gname gudas; do
        if echo "${gudas}" | tr ',' '\n' | grep -qxF "${uda_name}"; then
            echo "${gname}"
        fi
    done
}

# ── Write UDA groups block to .taskrc ─────────────────────────────────────────

# Write/update group block in .taskrc
# Accepts: group_name uda_csv [description]
_write_group() {
    local group_name="$1"
    local uda_csv="$2"
    local description="${3:-}"
    local taskrc="${TASKRC_FILE}"

    # Build the comment line
    local line="# group:${group_name} udas:${uda_csv}"
    [[ -n "${description}" ]] && line="${line} description:\"${description}\""

    if grep -q "^# === WW UDA GROUPS ===" "${taskrc}" 2>/dev/null; then
        # Block exists — replace or append line for this group
        if grep -q "^# group:${group_name} " "${taskrc}" 2>/dev/null; then
            sed -i.bak "s|^# group:${group_name} .*|${line}|" "${taskrc}"
            rm -f "${taskrc}.bak"
        else
            sed -i.bak "/^# === END WW UDA GROUPS ===/i\\
${line}" "${taskrc}"
            rm -f "${taskrc}.bak"
        fi
    else
        # Append new block
        printf '\n# === WW UDA GROUPS ===\n%s\n# === END WW UDA GROUPS ===\n' "${line}" >> "${taskrc}"
    fi
}

# Add a UDA to a group (adds to existing csv or creates group)
_add_uda_to_group() {
    local uda_name="$1"
    local group_name="$2"
    local existing_udas=""

    existing_udas=$(_read_groups | awk -v g="${group_name}" '$1==g{print $2}' || true)
    if [[ -z "${existing_udas}" ]]; then
        _write_group "${group_name}" "${uda_name}"
    else
        # Avoid duplicates
        if ! echo "${existing_udas}" | tr ',' '\n' | grep -qxF "${uda_name}"; then
            _write_group "${group_name}" "${existing_udas},${uda_name}"
        fi
    fi
}

# Remove a UDA from all groups in .taskrc
_remove_uda_from_groups() {
    local uda_name="$1"
    local taskrc="${TASKRC_FILE}"
    # Rewrite each group line, removing the UDA name from csv
    sed -i.bak "s/,${uda_name}//g; s/${uda_name},//g; s/udas:${uda_name} /udas: /g" "${taskrc}"
    rm -f "${taskrc}.bak"
}

# Mark a UDA as uncategorized (suppressed from default list)
_mark_uncategorized() {
    local uda_name="$1"
    local taskrc="${TASKRC_FILE}"
    local line="# uda:${uda_name} uncategorized"
    if ! grep -q "^# uda:${uda_name} " "${taskrc}" 2>/dev/null; then
        printf '%s\n' "${line}" >> "${taskrc}"
    fi
}

_is_uncategorized() {
    local uda_name="$1"
    grep -q "^# uda:${uda_name} uncategorized" "${TASKRC_FILE}" 2>/dev/null
}

# ── Indicator map helpers ──────────────────────────────────────────────────────

# Look up indicator character for a group name from uda-indicator-map.yaml.
# Falls back to ◆ (custom) if group not found or map not present.
_lookup_indicator() {
    local group_name="${1,,}"  # lowercase
    local indicator="◆"
    if [[ -f "${INDICATOR_MAP}" ]]; then
        local found
        found=$(awk '
            /^groups:/ { in_section=1; next }
            in_section && /^[a-z]/ && !/^  / { in_section=0 }
            in_section && $0 ~ "^  '"${group_name}"':" {
                line=$0; gsub(/^[^"]*"/, "", line); gsub(/".*$/, "", line); print line; exit
            }
        ' "${INDICATOR_MAP}" || true)
        [[ -n "${found}" ]] && indicator="${found}"
    fi
    echo "${indicator}"
}

# ── Color map helpers ──────────────────────────────────────────────────────────

# Look up TW color spec for a UDA — checks uda_overrides first, then group, then custom.
_lookup_color() {
    local uda_name="$1"
    local group_name="${2,,}"
    local color="yellow"

    if [[ ! -f "${COLOR_MAP}" ]]; then
        echo "${color}"
        return 0
    fi

    # Check per-UDA override (in uda_overrides: section)
    local override
    override=$(awk '
        /^uda_overrides:/ { in_section=1; next }
        in_section && /^[a-z]/ && !/^  / { in_section=0 }
        in_section && $0 ~ "^  '"${uda_name}"':" {
            line=$0; gsub(/^[^"]*"/, "", line); gsub(/".*$/, "", line); print line; exit
        }
    ' "${COLOR_MAP}" || true)
    if [[ -n "${override}" ]]; then
        echo "${override}"
        return 0
    fi

    # Check group color (in groups: section only)
    local group_color
    group_color=$(awk '
        /^groups:/ { in_section=1; next }
        in_section && /^[a-z]/ && !/^  / { in_section=0 }
        in_section && $0 ~ "^  '"${group_name}"':" {
            line=$0; gsub(/^[^"]*"/, "", line); gsub(/".*$/, "", line); print line; exit
        }
    ' "${COLOR_MAP}" || true)
    [[ -n "${group_color}" ]] && color="${group_color}"

    echo "${color}"
}

# Write/update the WW COLOR RULES block in .taskrc.
# Adds or replaces one color.uda.<name> line.
_write_color_rule() {
    local uda_name="$1"
    local color_spec="$2"
    local taskrc="${TASKRC_FILE}"
    local rule="color.uda.${uda_name}=${color_spec}"

    if grep -q "^# === WW COLOR RULES ===" "${taskrc}" 2>/dev/null; then
        if grep -q "^color\.uda\.${uda_name}=" "${taskrc}" 2>/dev/null; then
            sed -i.bak "s|^color\.uda\.${uda_name}=.*|${rule}|" "${taskrc}"
            rm -f "${taskrc}.bak"
        else
            sed -i.bak "/^# === END WW COLOR RULES ===/i\\
${rule}" "${taskrc}"
            rm -f "${taskrc}.bak"
        fi
    else
        printf '\n# === WW COLOR RULES ===\n%s\n# === END WW COLOR RULES ===\n' "${rule}" >> "${taskrc}"
    fi
}

# Write per-value color rules from COLOR_MAP for a UDA that has defined values.
_write_value_color_rules() {
    local uda_name="$1"
    if [[ ! -f "${COLOR_MAP}" ]]; then return 0; fi

    # Extract value_overrides.<uda_name> block from yaml
    local in_block=0
    while IFS= read -r line; do
        if [[ "${line}" =~ ^"  ${uda_name}:" ]]; then
            in_block=1
            continue
        fi
        if [[ "${in_block}" -eq 1 ]]; then
            # Stop at next same-level or higher key
            [[ "${line}" =~ ^"  "[a-z] ]] && break
            [[ "${line}" =~ ^[a-z] ]] && break
            # Parse "    <value>: <color_spec>"
            if [[ "${line}" =~ ^"    "([a-z_]+):\ +\"(.+)\"$ ]]; then
                local val="${BASH_REMATCH[1]}"
                local col="${BASH_REMATCH[2]}"
                _write_color_rule "${uda_name}.${val}" "${col}"
            fi
        fi
    done < "${COLOR_MAP}"
    return 0
}

# ── List subcommand ────────────────────────────────────────────────────────────

cmd_uda_list() {
    local show_all=0
    for arg in "$@"; do
        [[ "${arg}" == "--all" ]] && show_all=1
    done

    _resolve_profile

    # Read all UDA names from .taskrc
    local all_udas
    all_udas=$(grep -E '^uda\.[^.]+\.type=' "${TASKRC_FILE}" \
        | awk -F. '{print $2}' | sort -u || true)

    if [[ -z "${all_udas}" ]]; then
        echo "No UDAs defined for profile '${PROFILE_NAME}'."
        echo "  Add one with: ww profile uda add"
        return 0
    fi

    # Collect groups
    declare -A uda_groups_map
    while IFS=' ' read -r gname gudas; do
        for u in $(echo "${gudas}" | tr ',' ' '); do
            if [[ -n "${uda_groups_map[${u}]+_}" ]]; then
                uda_groups_map["${u}"]="${uda_groups_map[${u}]},${gname}"
            else
                uda_groups_map["${u}"]="${gname}"
            fi
        done
    done < <(_read_groups)

    # Determine which service sections have UDAs
    declare -A service_udas
    local user_udas=()
    local uncategorized_udas=()

    local uda
    for uda in ${all_udas}; do
        local svc
        svc=$(_uda_service "${uda}")
        if [[ -n "${svc}" ]]; then
            service_udas["${svc}"]="${service_udas[${svc}]:-}${uda} "
        elif _is_uncategorized "${uda}"; then
            uncategorized_udas+=("${uda}")
        else
            user_udas+=("${uda}")
        fi
    done

    # ── Service sections ──
    local has_service_section=0
    for svc in $(echo "${!service_udas[@]}" | tr ' ' '\n' | sort); do
        if [[ "${has_service_section}" -eq 0 ]]; then
            echo "━━━ Service-managed UDAs ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  (Do not rename or delete — managed by sync integrations)"
            has_service_section=1
        fi
        echo ""
        echo "  ▸ ${svc}"
        for uda in ${service_udas["${svc}"]}; do
            _print_uda_row "${uda}" "${uda_groups_map[${uda}]:-}"
        done
    done
    if [[ "${has_service_section}" -eq 1 ]]; then
        echo ""
        echo "  Add your own UDAs below. Service prefixes (github_, sync_, etc.) are"
        echo "  reserved — ww assigns them automatically when you connect a service."
        echo ""
    fi

    # ── User / grouped UDAs ──
    local printed_udas=()

    # Print group sections first
    while IFS=' ' read -r gname gudas; do
        local group_has_user_udas=0
        for uda in $(echo "${gudas}" | tr ',' ' '); do
            if ! _is_service_uda "${uda}"; then
                group_has_user_udas=1
                break
            fi
        done
        [[ "${group_has_user_udas}" -eq 0 ]] && continue

        echo "━━━ [${gname}] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for uda in $(echo "${gudas}" | tr ',' ' '); do
            _is_service_uda "${uda}" && continue
            _is_uncategorized "${uda}" && continue
            _print_uda_row "${uda}" "${uda_groups_map[${uda}]:-}"
            printed_udas+=("${uda}")
        done
        echo ""
    done < <(_read_groups)

    # Ungrouped user UDAs
    local ungrouped=()
    for uda in "${user_udas[@]}"; do
        local already=0
        for p in "${printed_udas[@]:-}"; do
            [[ "${p}" == "${uda}" ]] && already=1 && break
        done
        [[ "${already}" -eq 0 ]] && ungrouped+=("${uda}")
    done

    if [[ "${#ungrouped[@]}" -gt 0 ]]; then
        echo "━━━ Ungrouped ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for uda in "${ungrouped[@]}"; do
            _print_uda_row "${uda}" ""
        done
        echo ""
    fi

    # Uncategorized (requires --all)
    if [[ "${#uncategorized_udas[@]}" -gt 0 ]]; then
        if [[ "${show_all}" -eq 1 ]]; then
            echo "━━━ Uncategorized (hidden by default) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            for uda in "${uncategorized_udas[@]}"; do
                _print_uda_row "${uda}" ""
            done
            echo ""
        else
            echo "  (${#uncategorized_udas[@]} uncategorized UDA(s) hidden — use --all to show)"
        fi
    fi
}

_print_uda_row() {
    local uda="$1"
    local groups="$2"
    local type label values default perms_tag

    type=$(grep -E "^uda\\.${uda}\\.type=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
    type="${type:-string}"
    label=$(grep -E "^uda\\.${uda}\\.label=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
    values=$(grep -E "^uda\\.${uda}\\.values=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)

    # Permissions badge
    perms_tag=""
    if sp_has_permission "${PROFILE_BASE}" "${uda}" "nosync" 2>/dev/null; then
        perms_tag=" [nosync]"
    elif sp_has_permission "${PROFILE_BASE}" "${uda}" "private" 2>/dev/null; then
        perms_tag=" [private]"
    fi

    # Groups tag (multi-group)
    local groups_tag=""
    if [[ -n "${groups}" ]]; then
        groups_tag=" $(echo "${groups}" | tr ',' '\n' | awk '{printf "[%s]", $1}' | tr -d '\n')"
    fi

    local display_label=""
    [[ -n "${label}" && "${label}" != "${uda}" ]] && display_label=" \"${label}\""

    local display_values=""
    [[ -n "${values}" ]] && display_values=" (${values})"

    # Indicator char from .taskrc
    local indicator=""
    indicator=$(grep -E "^uda\\.${uda}\\.indicator=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
    local indicator_col=" "
    [[ -n "${indicator}" ]] && indicator_col="${indicator}"

    printf "  %s %-24s %-10s%s%s%s%s\n" \
        "${indicator_col}" \
        "${uda}" \
        "${type}" \
        "${display_label}" \
        "${display_values}" \
        "${groups_tag}" \
        "${perms_tag}"
}

# ── Add subcommand ─────────────────────────────────────────────────────────────

cmd_uda_add() {
    local preset_name="${1:-}"
    _resolve_profile

    echo ""
    echo "Add a new UDA to profile '${PROFILE_NAME}'"
    echo ""

    # ── Tier 1: name ──
    local uda_name="${preset_name}"
    if [[ -z "${uda_name}" ]]; then
        read -rp "  UDA name (lowercase, no spaces): " uda_name
    fi
    uda_name="${uda_name// /_}"
    uda_name="${uda_name,,}"
    if [[ -z "${uda_name}" ]]; then
        log_error "UDA name cannot be empty."
        exit 1
    fi
    if _is_service_uda "${uda_name}"; then
        log_error "'${uda_name}' uses a service-reserved prefix."
        exit 1
    fi
    local _check_type
    _check_type=$(grep -E "^uda\\.${uda_name}\\.type=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
    if [[ -n "${_check_type}" ]]; then
        log_error "UDA '${uda_name}' already exists (type: ${_check_type}). Use 'ww profile uda manage ${uda_name}' to edit."
        exit 1
    fi

    # ── Tier 1: type ──
    echo ""
    echo "  Type options: string  numeric  date  duration  boolean"
    read -rp "  Type [string]: " uda_type
    uda_type="${uda_type:-string}"
    case "${uda_type}" in
        string|numeric|date|duration|boolean) ;;
        *)
            log_error "Invalid type '${uda_type}'. Choose: string numeric date duration boolean"
            exit 1 ;;
    esac

    # ── Tier 2: label ──
    echo ""
    local auto_label
    auto_label=$(echo "${uda_name}" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
    read -rp "  Label [${auto_label}]: " uda_label
    uda_label="${uda_label:-${auto_label}}"

    # ── Tier 2: values (string only) ──
    local uda_values=""
    local uda_default=""
    if [[ "${uda_type}" == "string" ]]; then
        echo ""
        echo "  Allowed values (comma-separated, or Enter for any)."
        echo "  Tip: order matters — first value sorts highest in reports."
        echo "  Tip: trailing comma allows tasks to have no value set (e.g. 'low,medium,high,')"
        read -rp "  Values [any]: " uda_values

        if [[ -n "${uda_values}" ]]; then
            # Show order confirmation
            echo ""
            echo "  Values in order:"
            local i=1
            IFS=',' read -ra val_arr <<< "${uda_values%,}"
            for v in "${val_arr[@]}"; do
                echo "    ${i}. ${v}"
                i=$((i+1))
            done
            local trailing=""
            [[ "${uda_values}" == *"," ]] && trailing=" (trailing comma = unset allowed)"
            echo "  ${trailing}"
            echo ""
            echo "  Type numbers in new order (e.g. '3 1 2'), or press Enter to confirm."
            read -rp "  Order: " new_order
            if [[ -n "${new_order}" ]]; then
                local reordered=""
                for idx in ${new_order}; do
                    local zero_idx=$((idx-1))
                    if [[ "${zero_idx}" -ge 0 && "${zero_idx}" -lt "${#val_arr[@]}" ]]; then
                        reordered="${reordered:+${reordered},}${val_arr[${zero_idx}]}"
                    fi
                done
                [[ "${uda_values}" == *"," ]] && reordered="${reordered},"
                uda_values="${reordered}"
            fi

            # Default value
            local trailing_comma=0
            [[ "${uda_values}" == *"," ]] && trailing_comma=1
            echo ""
            if [[ "${trailing_comma}" -eq 1 ]]; then
                echo "  Default value (Enter for none — trailing comma allows unset):"
            else
                echo "  Default value (must be one of the values above, or Enter for none):"
            fi
            read -rp "  Default [none]: " uda_default
        fi
    fi

    # ── Tier 2: group assignment ──
    echo ""
    local existing_groups
    existing_groups=$(_read_groups | awk '{print $1}')
    local chosen_group=""
    if [[ -n "${existing_groups}" ]]; then
        echo "  Assign to a group? Existing groups:"
        local gi=1
        while IFS= read -r g; do
            echo "    ${gi}. ${g}"
            gi=$((gi+1))
        done <<< "${existing_groups}"
        echo "    n. New group"
        echo "    Enter to skip"
        read -rp "  Group [skip]: " group_choice
        if [[ "${group_choice}" =~ ^[0-9]+$ ]]; then
            local gi2=1
            while IFS= read -r g; do
                if [[ "${gi2}" -eq "${group_choice}" ]]; then
                    chosen_group="${g}"
                    break
                fi
                gi2=$((gi2+1))
            done <<< "${existing_groups}"
        elif [[ "${group_choice}" == "n" || "${group_choice}" == "N" ]]; then
            read -rp "  New group name: " chosen_group
            chosen_group="${chosen_group// /_}"
        fi
    else
        echo "  No groups defined yet. Create one? (Enter to skip, or type a group name)"
        read -rp "  Group name: " chosen_group
        chosen_group="${chosen_group// /_}"
    fi

    # ── Write to .taskrc ──
    echo ""
    TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".type "${uda_type}" >/dev/null
    TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".label "${uda_label}" >/dev/null
    [[ -n "${uda_values}" ]] && TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".values "${uda_values}" >/dev/null
    [[ -n "${uda_default}" ]] && TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".default "${uda_default}" >/dev/null

    echo "  ✓ UDA '${uda_name}' added (${uda_type})."

    if [[ -n "${chosen_group}" ]]; then
        _add_uda_to_group "${uda_name}" "${chosen_group}"
        echo "  ✓ Added to group '${chosen_group}'."

        # ── Indicator (UDA-002) ──
        local indicator
        indicator=$(_lookup_indicator "${chosen_group}")
        TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".indicator "${indicator}" >/dev/null
        echo "  ✓ Indicator set: ${indicator}"

        # ── Color (UDA-003) ──
        local color_spec
        color_spec=$(_lookup_color "${uda_name}" "${chosen_group}")
        _write_color_rule "${uda_name}" "${color_spec}"
        echo "  ✓ Color rule written: color.uda.${uda_name}=${color_spec}"

        # Write per-value color rules if values were defined
        [[ -n "${uda_values}" ]] && _write_value_color_rules "${uda_name}"
    fi

    echo ""
    echo "  Use 'ww profile uda list' to see all UDAs."
}

# ── Remove subcommand ──────────────────────────────────────────────────────────

cmd_uda_remove() {
    local uda_name="${1:-}"
    _resolve_profile

    if [[ -z "${uda_name}" ]]; then
        log_error "Usage: ww profile uda remove <name>"
        exit 1
    fi

    if _is_service_uda "${uda_name}"; then
        log_error "'${uda_name}' is service-managed. Removing it will break sync."
        echo "  If you really need to remove it, edit ${TASKRC_FILE} directly." >&2
        exit 1
    fi

    local existing_type
    existing_type=$(grep -E "^uda\\.${uda_name}\\.type=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
    if [[ -z "${existing_type}" ]]; then
        log_error "UDA '${uda_name}' not found in profile '${PROFILE_NAME}'."
        exit 1
    fi

    read -rp "Remove UDA '${uda_name}' (type: ${existing_type})? This cannot be undone. [y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && echo "Aborted." && return 0

    TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".type "" >/dev/null 2>&1 || true
    TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".label "" >/dev/null 2>&1 || true
    TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".values "" >/dev/null 2>&1 || true
    TASKRC="${TASKRC_FILE}" task rc.confirmation=no config uda."${uda_name}".default "" >/dev/null 2>&1 || true
    _remove_uda_from_groups "${uda_name}"
    sp_set_permissions "${PROFILE_BASE}" "${uda_name}" ""

    echo "✓ UDA '${uda_name}' removed."
}

# ── Group subcommand ───────────────────────────────────────────────────────────

cmd_uda_group() {
    local uda_name="${1:-}"
    local group_name="${2:-}"
    _resolve_profile

    if [[ -z "${uda_name}" ]]; then
        log_error "Usage: ww profile uda group <uda-name> [group-name]"
        exit 1
    fi

    local existing_type
    existing_type=$(grep -E "^uda\\.${uda_name}\\.type=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
    if [[ -z "${existing_type}" ]]; then
        log_error "UDA '${uda_name}' not found."
        exit 1
    fi

    if [[ -z "${group_name}" ]]; then
        local current_groups
        current_groups=$(_groups_for_uda "${uda_name}" | tr '\n' ',' | sed 's/,$//')
        echo "UDA '${uda_name}' current groups: ${current_groups:-none}"
        echo ""
        local existing_groups
        existing_groups=$(_read_groups | awk '{print $1}')
        if [[ -n "${existing_groups}" ]]; then
            echo "Available groups:"
            local gi=1
            while IFS= read -r g; do
                echo "  ${gi}. ${g}"
                gi=$((gi+1))
            done <<< "${existing_groups}"
            echo "  n. New group"
        fi
        read -rp "Group name (or number): " group_name
        if [[ "${group_name}" =~ ^[0-9]+$ ]]; then
            local gi2=1
            while IFS= read -r g; do
                if [[ "${gi2}" -eq "${group_name}" ]]; then
                    group_name="${g}"
                    break
                fi
                gi2=$((gi2+1))
            done <<< "${existing_groups}"
        elif [[ "${group_name}" == "n" ]]; then
            read -rp "New group name: " group_name
        fi
        group_name="${group_name// /_}"
    fi

    [[ -z "${group_name}" ]] && echo "No group selected." && return 0

    _add_uda_to_group "${uda_name}" "${group_name}"
    echo "✓ UDA '${uda_name}' added to group '${group_name}'."
}

# ── Perm subcommand ────────────────────────────────────────────────────────────

cmd_uda_perm() {
    local uda_name="${1:-}"
    shift || true
    _resolve_profile

    if [[ -z "${uda_name}" ]]; then
        log_error "Usage: ww profile uda perm <name> [tokens...]"
        echo "" >&2
        echo "  Valid tokens: nosync  deny:<svc>  deny:<svc>:<ch>  readonly  writeonly" >&2
        echo "                private  noreport  noexport  noai  managed  locked" >&2
        exit 1
    fi

    if [[ "$#" -eq 0 ]]; then
        # Show mode
        local perms
        perms=$(sp_get_permissions "${PROFILE_BASE}" "${uda_name}" | tr '\n' ',' | sed 's/,$//')
        if [[ -z "${perms}" ]]; then
            echo "UDA '${uda_name}': no sync permissions set (default: all sync allowed)"
        else
            echo "UDA '${uda_name}' permissions: ${perms}"
        fi
        return 0
    fi

    # Set mode: replace all permissions with the given tokens
    local tokens
    tokens=$(printf '%s,' "$@")
    tokens="${tokens%,}"
    sp_set_permissions "${PROFILE_BASE}" "${uda_name}" "${tokens}"
    echo "✓ Permissions for '${uda_name}' set to: ${tokens}"
}

# ── Help ───────────────────────────────────────────────────────────────────────

show_uda_help() {
    cat << 'EOF'
UDA Management

Usage: ww profile uda <subcommand> [arguments]

Subcommands:
  list [--all]              List all UDAs for the active profile
  add [<name>]              Add a new UDA (interactive wizard)
  remove <name>             Remove a UDA
  group <name> [group]      Assign UDA to a group (interactive if group omitted)
  color <name> [spec]       Show or set the TW color rule for a UDA
  perm <name> [tokens...]   Show or set sync permissions for a UDA
  help                      Show this help

Aliases:
  ww profile udas           Same as 'ww profile uda list'

Sync permission tokens:
  nosync         Never sync this UDA (any service, any direction)
  deny:<svc>     Block all sync for a specific service (e.g. deny:bugwarrior)
  readonly       External services can read but not write
  writeonly      External services can write but not read
  private        Exclude from any export visible to other users
  noreport       Hide from report output
  noai           Exclude from AI context

Examples:
  ww profile uda list
  ww profile uda list --all
  ww profile uda add
  ww profile uda add goals
  ww profile uda remove phase
  ww profile uda group goals work
  ww profile uda color goals
  ww profile uda color goals "bold green"
  ww profile uda perm goals nosync,noai
  ww profile uda perm goals

Note:
  UDAs from connected services (bugwarrior, github-sync) are shown separately.
  Do not rename or delete service-managed UDAs — it will break sync.
  Indicators and color rules are auto-assigned based on group at add time.
  Use 'ww profile uda color' to override per UDA.
EOF
}

# ── Color subcommand ───────────────────────────────────────────────────────────

cmd_uda_color() {
    local uda_name="${1:-}"
    local color_spec="${2:-}"
    _resolve_profile

    if [[ -z "${uda_name}" ]]; then
        log_error "Usage: ww profile uda color <name> [spec]"
        echo "  Valid specs: blue  green  red  yellow  cyan  white  bold green  rgb:255/165/0  etc." >&2
        exit 1
    fi

    if [[ -z "${color_spec}" ]]; then
        # Show current color for this UDA
        local current
        current=$(grep -E "^color\.uda\.${uda_name}=" "${TASKRC_FILE}" | cut -d= -f2 | head -1 || true)
        if [[ -n "${current}" ]]; then
            echo "color.uda.${uda_name}=${current}"
        else
            echo "UDA '${uda_name}': no color rule set"
            echo "  Set with: ww profile uda color ${uda_name} <spec>"
        fi
        return 0
    fi

    _write_color_rule "${uda_name}" "${color_spec}"
    echo "✓ color.uda.${uda_name}=${color_spec}"
}

# ── Dispatch ───────────────────────────────────────────────────────────────────

main() {
    local subcommand="${1:-list}"
    shift || true

    case "${subcommand}" in
        list|ls)         cmd_uda_list "$@" ;;
        add)             cmd_uda_add "$@" ;;
        remove|rm|del)   cmd_uda_remove "$@" ;;
        group)           cmd_uda_group "$@" ;;
        color)           cmd_uda_color "$@" ;;
        perm|perms)      cmd_uda_perm "$@" ;;
        help|-h|--help)  show_uda_help ;;
        *)
            log_error "Unknown uda subcommand: ${subcommand}"
            show_uda_help
            exit 1 ;;
    esac
}

main "$@"
