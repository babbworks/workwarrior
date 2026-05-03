#!/usr/bin/env bash
set -euo pipefail
#
# services/profile/subservices/profile-density.sh
# ww profile density <subcommand> — TWDensity due-date density urgency scoring
#
# Upstream: https://github.com/00sapo/TWDensity
# Author:   00sapo · MIT License
#
# Subcommands:
#   install       Install twdensity via pipx + write UDAs to active profile .taskrc
#   run           Run twdensity to update density values for all tasks
#   config        Show current density UDA config in .taskrc
#   help          Show this help

_DENSITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_WW_BASE="$(cd "${_DENSITY_DIR}/../../.." && pwd)"

source "${_WW_BASE}/lib/core-utils.sh"

_resolve_profile() {
    if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        log_error "No active profile. Activate with: p-<profile-name>"
        exit 1
    fi
    PROFILE_BASE="${WORKWARRIOR_BASE}"
    PROFILE_NAME="${WARRIOR_PROFILE:-$(basename "${PROFILE_BASE}")}"
    TASKRC_FILE="${TASKRC:-${PROFILE_BASE}/.taskrc}"
    TASKDATA_DIR="${TASKDATA:-${PROFILE_BASE}/.task}"
}

# Idempotently write TWDensity UDA config to active profile .taskrc
_write_density_udas() {
    local taskrc="$1"

    # density UDA
    if ! grep -q "^uda\.density\.type=" "${taskrc}" 2>/dev/null; then
        TASKRC="${taskrc}" task rc.confirmation=no config uda.density.type numeric >/dev/null
        TASKRC="${taskrc}" task rc.confirmation=no config uda.density.label "Due Density" >/dev/null
    fi

    # densitywindow UDA
    if ! grep -q "^uda\.densitywindow\.type=" "${taskrc}" 2>/dev/null; then
        TASKRC="${taskrc}" task rc.confirmation=no config uda.densitywindow.type numeric >/dev/null
        TASKRC="${taskrc}" task rc.confirmation=no config uda.densitywindow.label "Density Window" >/dev/null
        TASKRC="${taskrc}" task rc.confirmation=no config uda.densitywindow.default 5 >/dev/null
    fi

    # Default urgency coefficients (from TWDensity docs — 0 to 5 over 30 levels)
    local i coeff
    for i in $(seq 0 30); do
        if ! grep -q "^urgency\.uda\.density\.${i}\.coefficient=" "${taskrc}" 2>/dev/null; then
            coeff=$(awk "BEGIN {printf \"%.2f\", ${i} * 5 / 30}")
            TASKRC="${taskrc}" task rc.confirmation=no \
                config "urgency.uda.density.${i}.coefficient" "${coeff}" >/dev/null
        fi
    done
}

cmd_density_install() {
    _resolve_profile

    # Check/install twdensity
    if command -v twdensity &>/dev/null; then
        log_success "twdensity already installed: $(twdensity --version 2>/dev/null || echo 'version unknown')"
    else
        if ! command -v pipx &>/dev/null; then
            log_error "pipx not found. Install with: brew install pipx"
            exit 1
        fi
        echo "Installing twdensity..."
        echo "  Upstream: https://github.com/00sapo/TWDensity"
        echo "  Author:   00sapo · MIT License"
        pipx install twdensity
        log_success "twdensity installed"
    fi

    echo ""
    echo "Writing density UDAs to profile '${PROFILE_NAME}'..."
    _write_density_udas "${TASKRC_FILE}"
    echo "  ✓ uda.density.type=numeric"
    echo "  ✓ uda.densitywindow.type=numeric (default: 5)"
    echo "  ✓ urgency.uda.density.0..30.coefficient written"
    echo ""
    echo "Run 'ww profile density run' to update density values."
    echo ""
    echo "Powered by TWDensity · 00sapo"
    echo "  https://github.com/00sapo/TWDensity · MIT License"
}

cmd_density_run() {
    _resolve_profile

    if ! command -v twdensity &>/dev/null; then
        log_error "twdensity not installed. Run: ww profile density install"
        exit 1
    fi

    echo "Running TWDensity for profile '${PROFILE_NAME}'..."
    TASKRC="${TASKRC_FILE}" TASKDATA="${TASKDATA_DIR}" twdensity "$@"
    log_success "Density values updated."
}

cmd_density_config() {
    _resolve_profile

    echo "TWDensity config for profile '${PROFILE_NAME}':"
    echo ""
    echo "  UDAs:"
    grep -E "^uda\.(density|densitywindow)\." "${TASKRC_FILE}" 2>/dev/null \
        | sed 's/^/    /' || echo "    (not installed — run: ww profile density install)"
    echo ""
    echo "  Urgency coefficients (first 5):"
    grep -E "^urgency\.uda\.density\.[0-9]+\.coefficient=" "${TASKRC_FILE}" 2>/dev/null \
        | head -5 | sed 's/^/    /' || echo "    (none set)"
    local total
    total=$(grep -c "^urgency\.uda\.density\." "${TASKRC_FILE}" 2>/dev/null || echo 0)
    [[ "${total}" -gt 5 ]] && echo "    ... (${total} total)"
    echo ""
    echo "  twdensity: $(command -v twdensity 2>/dev/null || echo 'not installed')"
}

show_density_help() {
    cat << 'EOF'
ww profile density — due-date density urgency scoring

Adjusts task urgency based on how many tasks share a similar due date.
Prevents urgency spikes when tasks cluster on the same date.

Usage:
  ww profile density install    Install twdensity + write UDAs to active profile
  ww profile density run        Update density values for all tasks
  ww profile density config     Show current density config in .taskrc
  ww profile density help       Show this help

UDAs added:
  density        Numeric — count of tasks with similar due dates
  densitywindow  Numeric — window size in days (default: 5)

After install, run 'ww profile density run' periodically or add it to a
routine (ww routines) to keep density values current.

Powered by TWDensity · 00sapo
  https://github.com/00sapo/TWDensity · MIT License
EOF
}

main() {
    local subcommand="${1:-help}"
    shift || true

    case "${subcommand}" in
        install)         cmd_density_install "$@" ;;
        run)             cmd_density_run "$@" ;;
        config)          cmd_density_config "$@" ;;
        help|-h|--help)  show_density_help ;;
        *)
            log_error "Unknown density subcommand: ${subcommand}"
            show_density_help
            exit 1 ;;
    esac
}

main "$@"
