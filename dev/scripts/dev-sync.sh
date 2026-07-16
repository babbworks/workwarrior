#!/usr/bin/env bash
# dev/scripts/dev-sync.sh — sync program files from repo to a ww instance
#
# Usage:
#   bash dev/scripts/dev-sync.sh              # dry-run: prompt for target, show what would change
#   bash dev/scripts/dev-sync.sh --apply      # prompt for target, apply
#   bash dev/scripts/dev-sync.sh --apply --target ~/ww   # sync to specified target
#   bash dev/scripts/dev-sync.sh --apply --service browser   # sync only services/browser/
#   bash dev/scripts/dev-sync.sh --service browser           # dry-run single service
#
# If no --target is given, the script prompts interactively with discovered
# instances (~/ww, ~/ww). Non-interactive invocations require --target.
#
# What is synced (program files only):
#   bin/          CLI dispatcher and helpers
#   lib/          Core bash libraries
#   tools/        Bundled tools (list.py, etc.) — program code, not user data
#   services/     Service scripts (warlock, browser, community, etc.)
#   resources/    Default templates
#   weapons/      Weapon extensions
#   config/shortcuts.yaml         routing table — program file
#   config/extensions.*.yaml      extension manifests — program file
#   config/profile-meta-template.yaml
#   config/heuristics.yaml        (if present)
#
# What is NOT synced:
#   profiles/         user task/time/journal/ledger data
#   functions/        personal shell functions / user data
#   test-profiles/    bats test artifacts
#   dev/              dev control plane (not shipped)
#   docs/             documentation (update separately)
#   stories/          marketing copy
#   pending/          archive
#   .state/           runtime state files
#   .task/            task data
#   .community/       community data
#   .claude/          agent config
#   node_modules/     npm deps
#   config/groups.yaml            user-configured
#   config/projects.yaml          user-configured
#   config/ai.yaml                user-configured
#   config/ctrl.yaml              user-configured
#   config/models.yaml            user-configured
#   config/cmd-heuristics*.yaml   generated

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET=""
DRY_RUN=1
SERVICE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)       DRY_RUN=0 ;;
    --target)      shift; TARGET="$1" ;;
    --target=*)    TARGET="${1#--target=}" ;;
    --service)     shift; SERVICE="$1" ;;
    --service=*)   SERVICE="${1#--service=}" ;;
    --help|-h)
      sed -n '2,/^set /p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
  esac
  shift
done

# If no target specified, prompt interactively
if [[ -z "$TARGET" ]]; then
  echo "Sync target directory:"
  echo ""
  local_targets=()
  idx=1
  for candidate in "${HOME}/ww" "${HOME}/ww"; do
    if [[ -d "$candidate" ]]; then
      local_targets+=("$candidate")
      echo "  ${idx}. ${candidate}"
      idx=$((idx + 1))
    fi
  done
  if [[ ${#local_targets[@]} -eq 0 ]]; then
    echo "  No known ww instances found (checked ~/ww, ~/ww)." >&2
    echo "  Use --target <path> to specify." >&2
    exit 1
  fi
  echo ""
  if [[ -t 0 ]]; then
    printf "Select [number or path]: "
    read -r selection
    if [[ -z "$selection" ]]; then
      echo "Cancelled."
      exit 0
    elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#local_targets[@]} )); then
      TARGET="${local_targets[$((selection - 1))]}"
    elif [[ -d "$selection" ]]; then
      TARGET="$selection"
    else
      echo "ERROR: invalid selection: $selection" >&2
      exit 1
    fi
  else
    echo "Non-interactive — use --target <path>" >&2
    exit 1
  fi
fi

TARGET="${TARGET%/}"  # strip trailing slash

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: target directory does not exist: $TARGET" >&2
  exit 1
fi

# ── Service-targeted sync ───────────────────────────────────────────────────
if [[ -n "$SERVICE" ]]; then
  SRC="${REPO_ROOT}/services/${SERVICE}/"
  DST="${TARGET}/services/${SERVICE}/"
  if [[ ! -d "$SRC" ]]; then
    echo "ERROR: services/${SERVICE} not found in source (${REPO_ROOT})" >&2; exit 1
  fi
  if [[ ! -d "$DST" ]]; then
    mkdir -p "$DST"
  fi

  RSYNC_OPTS=(-av --delete)
  [[ "$DRY_RUN" -eq 1 ]] && RSYNC_OPTS+=(--dry-run)

  # Minimal exclusions for service sync
  SERVICE_EXCLUDES=(
    --exclude='*.pyc'
    --exclude='__pycache__/'
    --exclude='.DS_Store'
  )

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY RUN — service sync: ${SERVICE}"
    echo "  from: ${SRC}"
    echo "  to:   ${DST}"
    echo ""
  fi

  rsync "${RSYNC_OPTS[@]}" "${SERVICE_EXCLUDES[@]}" "$SRC" "$DST"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    echo "Re-run with --apply to apply these changes."
  else
    echo ""
    echo "Sync complete: services/${SERVICE} → ${TARGET}/services/${SERVICE}"
    if [[ "$SERVICE" == "browser" ]]; then
      echo "If browser is running, restart it:"
      echo "  pkill -f server.py && python3 ${TARGET}/services/browser/server.py --ww-base ${TARGET} --port <port> &"
    fi
  fi
  exit 0
fi

# ── Full sync ───────────────────────────────────────────────────────────────
RSYNC_OPTS=(-av --delete)
[[ "$DRY_RUN" -eq 1 ]] && RSYNC_OPTS+=(--dry-run)

EXCLUDES=(
  # user data (NEVER sync — lives only on the target instance)
  --exclude='profiles/'
  --exclude='functions/'
  --exclude='test-profiles/'
  --exclude='.community/'
  --exclude='.claude/'
  --exclude='.state/'
  --exclude='.task/'
  --exclude='.timewarrior/'
  # dev-only
  --exclude='dev/tests/'
  --exclude='dev/'
  --exclude='docs/'
  --exclude='stories/'
  --exclude='pending/'
  --exclude='devdev/'
  # generated / user-configured config
  --exclude='config/groups.yaml'
  --exclude='config/projects.yaml'
  --exclude='config/ai.yaml'
  --exclude='config/ctrl.yaml'
  --exclude='config/models.yaml'
  --exclude='config/cmd-heuristics.yaml'
  --exclude='config/cmd-heuristics-corpus.yaml'
  # build artifacts
  --exclude='node_modules/'
  --exclude='*.pyc'
  --exclude='__pycache__/'
  --exclude='.DS_Store'
  --exclude='.git/'
  --exclude='.github/'
  --exclude='.kiro/'
  --exclude='.gitbook.yaml'
  --exclude='.pytest_cache/'
  --exclude='.worktrees/'
  --exclude='.vscode/'
  # bookbuilder has its own .git and .venv
  --exclude='services/bookbuilder/'
  # repo-only files
  --exclude='test-profiles-scripts/'
  --exclude='test-ww-scripts/'
  --exclude='package.json'
  --exclude='package-lock.json'
  --exclude='*.md'
  --exclude='readme.md'
  --exclude='uninstall.sh'
  --exclude='install.sh'
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN — changes that would be applied to ${TARGET}:"
  echo "(run with --apply to execute)"
  echo ""
fi

rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" "${REPO_ROOT}/" "${TARGET}/"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "Re-run with --apply to apply these changes."
else
  echo ""
  echo "Sync complete: ${REPO_ROOT} → ${TARGET}"
fi
