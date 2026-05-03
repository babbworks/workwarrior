#!/usr/bin/env bash
# lib/sync-permissions.sh — Read and write UDA sync-permissions for a profile
#
# Storage: profiles/<name>/.config/sync-permissions
# Format:  one rule per line — <uda_name> <permission>[,<permission>...]
# Example: goals nosync,noai
#          phase deny:bugwarrior
#          github_url readonly,noreport
#
# Permission tokens:
#   nosync        — never sync this UDA (in or out, any service)
#   deny:<svc>    — deny all sync for named service (e.g. deny:bugwarrior)
#   deny:<svc>:<ch> — deny specific channel (e.g. deny:github-sync:push)
#   readonly      — external services may read but not write this UDA
#   writeonly     — external services may write but not read this UDA
#   private       — exclude from any export/report visible to other users
#   noreport      — hide from ww profile uda list output
#   noexport      — exclude from profile backup exports
#   noai          — do not include in AI context or prompts
#   managed       — ww-managed field; warn user before allowing manual edit
#   locked        — field is immutable; only set at creation time

# No set -euo pipefail here — this is a sourced lib

_SP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Return the sync-permissions file path for a profile base dir
_sp_file() {
    local profile_base="$1"
    echo "${profile_base}/.config/sync-permissions"
}

# Read all permissions for a UDA name.
# Outputs one permission token per line.
# Returns 0 even if no permissions set (just no output).
sp_get_permissions() {
    local profile_base="$1"
    local uda_name="$2"
    local sp_file
    sp_file="$(_sp_file "${profile_base}")"
    [[ -f "${sp_file}" ]] || return 0
    local line
    while IFS= read -r line; do
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        local name="${line%% *}"
        local perms="${line#* }"
        if [[ "${name}" == "${uda_name}" ]]; then
            tr ',' '\n' <<< "${perms}"
            return 0
        fi
    done < "${sp_file}"
    return 0
}

# Test whether a UDA has a specific permission token.
# Returns 0 (true) if permission is set, 1 otherwise.
sp_has_permission() {
    local profile_base="$1"
    local uda_name="$2"
    local token="$3"
    sp_get_permissions "${profile_base}" "${uda_name}" | grep -qxF "${token}"
}

# Set permissions for a UDA. Replaces any existing entry for that UDA.
# Permissions is a comma-separated list: "nosync,noai"
# Pass empty string to clear all permissions for the UDA.
sp_set_permissions() {
    local profile_base="$1"
    local uda_name="$2"
    local permissions="$3"
    local sp_file
    sp_file="$(_sp_file "${profile_base}")"

    # Ensure .config dir exists
    mkdir -p "$(dirname "${sp_file}")"

    if [[ ! -f "${sp_file}" ]]; then
        touch "${sp_file}"
    fi

    # Remove existing line for this UDA (if any)
    local tmp
    tmp="$(grep -v "^${uda_name} " "${sp_file}" 2>/dev/null || true)"

    if [[ -n "${permissions}" ]]; then
        printf '%s\n' "${tmp}" > "${sp_file}"
        echo "${uda_name} ${permissions}" >> "${sp_file}"
    else
        printf '%s\n' "${tmp}" > "${sp_file}"
    fi

    # Remove trailing blank lines
    sed -i.bak '/^[[:space:]]*$/d' "${sp_file}" && rm -f "${sp_file}.bak"
    return 0
}

# Add one or more permission tokens to a UDA's existing permissions.
# Tokens passed as separate arguments.
sp_add_permission() {
    local profile_base="$1"
    local uda_name="$2"
    shift 2
    local existing
    existing=$(sp_get_permissions "${profile_base}" "${uda_name}" | tr '\n' ',')
    existing="${existing%,}"
    local token
    for token in "$@"; do
        if ! sp_has_permission "${profile_base}" "${uda_name}" "${token}"; then
            existing="${existing:+${existing},}${token}"
        fi
    done
    sp_set_permissions "${profile_base}" "${uda_name}" "${existing}"
}

# Remove one permission token from a UDA.
sp_remove_permission() {
    local profile_base="$1"
    local uda_name="$2"
    local token="$3"
    local existing
    existing=$(sp_get_permissions "${profile_base}" "${uda_name}" | grep -vxF "${token}" | tr '\n' ',' || true)
    existing="${existing%,}"
    sp_set_permissions "${profile_base}" "${uda_name}" "${existing}"
}

# List all UDAs that have any permissions set.
# Outputs: uda_name  permissions  (tab-separated)
sp_list_all() {
    local profile_base="$1"
    local sp_file
    sp_file="$(_sp_file "${profile_base}")"
    [[ -f "${sp_file}" ]] || return 0
    local line
    while IFS= read -r line; do
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        echo "${line}"
    done < "${sp_file}"
}
