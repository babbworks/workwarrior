#!/usr/bin/env bash
# sync.sh — sync program files from this repo into a registered ww instance
#
# Usage:
#   ./sync.sh                              # dry-run: show registered instances, pick one
#   ./sync.sh --apply                      # pick instance interactively, apply
#   ./sync.sh --apply --target ~/ww        # sync to specified path directly
#   ./sync.sh --apply --instance main      # sync to registered instance by id/alias
#   ./sync.sh --apply --service browser    # sync only services/browser/
#   ./sync.sh --service browser            # dry-run single service
#   ./sync.sh --apply --include-dev        # include dev/ in sync
#   ./sync.sh --apply --include-docs       # include docs/ in sync
#
# Instance discovery uses ~/.config/ww/registry/ manifests.
# Hidden instances are excluded from the picker (use --instance to target directly).
#
# What is synced (program files only):
#   bin/          CLI dispatcher and helpers
#   lib/          Core bash libraries
#   tools/        Bundled tools (list.py, etc.)
#   services/     Service scripts (warlock, browser, community, etc.)
#   scripts/      Standalone scripts (popup, build-*)
#   resources/    Default templates
#   weapons/      Weapon extensions
#   config/shortcuts.yaml         routing table
#   config/extensions.*.yaml      extension manifests
#   config/profile-meta-template.yaml
#   config/heuristics.yaml        (if present)
#
# What is NOT synced:
#   profiles/         user task/time/journal/ledger data
#   functions/        personal shell functions
#   test-profiles/    test artifacts
#   dev/              dev control plane
#   docs/             documentation
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""
DRY_RUN=1
SERVICE=""
INSTANCE=""
INCLUDE_DEV=0
INCLUDE_DOCS=0

WW_CONFIG_HOME="${WW_CONFIG_HOME:-$HOME/.config/ww}"
REGISTRY_DIR="${WW_REGISTRY_DIR:-$WW_CONFIG_HOME/registry}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)        DRY_RUN=0 ;;
    --target)       shift; TARGET="$1" ;;
    --target=*)     TARGET="${1#--target=}" ;;
    --instance)     shift; INSTANCE="$1" ;;
    --instance=*)   INSTANCE="${1#--instance=}" ;;
    --service)      shift; SERVICE="$1" ;;
    --service=*)    SERVICE="${1#--service=}" ;;
    --include-dev)  INCLUDE_DEV=1 ;;
    --include-docs) INCLUDE_DOCS=1 ;;
    --help|-h)
      sed -n '2,/^set /p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Resolve target from --instance flag ─────────────────────────────────────
if [[ -n "$INSTANCE" ]]; then
  if [[ ! -d "$REGISTRY_DIR" ]]; then
    echo "ERROR: No instance registry found at $REGISTRY_DIR" >&2
    exit 1
  fi
  # Look up by id or alias (includes hidden — direct targeting bypasses visibility)
  TARGET=$(python3 - "$REGISTRY_DIR" "$INSTANCE" << 'PY'
import json, sys, os
reg_dir, key = sys.argv[1], sys.argv[2]
for f in os.listdir(reg_dir):
    if not f.endswith('.json'): continue
    d = json.load(open(os.path.join(reg_dir, f)))
    if d.get('id') == key or d.get('alias') == key:
        print(d.get('install_path', ''))
        sys.exit(0)
print('')
sys.exit(1)
PY
  ) || true
  if [[ -z "$TARGET" ]]; then
    echo "ERROR: Instance '$INSTANCE' not found in registry" >&2
    exit 1
  fi
fi

# ── Interactive instance picker (excludes hidden) ───────────────────────────
if [[ -z "$TARGET" ]]; then
  if [[ ! -d "$REGISTRY_DIR" ]] || [[ -z "$(ls "$REGISTRY_DIR"/*.json 2>/dev/null)" ]]; then
    echo "No registered instances found." >&2
    echo "Use --target <path> to specify a directory directly." >&2
    exit 1
  fi

  echo "Registered instances:"
  echo ""

  # Collect visible instances
  declare -a inst_ids=()
  declare -a inst_paths=()
  declare -a inst_aliases=()
  local idx=1

  while IFS=$'\t' read -r iid ialias iver ivis istatus ipath; do
    [[ -z "$iid" ]] && continue
    inst_ids+=("$iid")
    inst_paths+=("$ipath")
    inst_aliases+=("$ialias")
    local label="$ialias"
    [[ "$ialias" != "$iid" ]] && label="$ialias ($iid)"
    printf "  %d. %-20s  %s  [%s]\n" "$idx" "$label" "$ipath" "$istatus"
    idx=$((idx + 1))
  done < <(
    for f in "$REGISTRY_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      python3 - "$f" << 'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("visibility") == "hidden":
    sys.exit(0)
if d.get("status") != "active":
    sys.exit(0)
print(f"{d.get('id','')}\t{d.get('alias','')}\t{d.get('version','')}\t{d.get('visibility','visible')}\t{d.get('status','active')}\t{d.get('install_path','')}")
PY
    done
  )

  if [[ ${#inst_ids[@]} -eq 0 ]]; then
    echo "  No visible instances found." >&2
    echo "  Use --target <path> or --instance <id> to specify directly." >&2
    exit 1
  fi

  echo ""
  if [[ ! -t 0 ]]; then
    echo "Non-interactive — use --target <path> or --instance <id>" >&2
    exit 1
  fi

  printf "Select [number or path]: "
  read -r selection

  if [[ -z "$selection" ]]; then
    echo "Cancelled."
    exit 0
  elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#inst_ids[@]} )); then
    TARGET="${inst_paths[$((selection - 1))]}"
  elif [[ -d "$selection" ]]; then
    TARGET="$selection"
  else
    echo "ERROR: invalid selection: $selection" >&2
    exit 1
  fi
fi

TARGET="${TARGET%/}"

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: target directory does not exist: $TARGET" >&2
  exit 1
fi

if [[ "$REPO_ROOT" -ef "$TARGET" ]]; then
  echo "ERROR: source and target are the same directory" >&2
  exit 1
fi

# ── Verify rsync is available ───────────────────────────────────────────────
if ! command -v rsync >/dev/null 2>&1; then
  echo "ERROR: rsync is required but not installed." >&2
  echo "  sudo apt install rsync" >&2
  exit 1
fi

# ── Service-targeted sync ───────────────────────────────────────────────────
if [[ -n "$SERVICE" ]]; then
  SRC="${REPO_ROOT}/services/${SERVICE}/"
  DST="${TARGET}/services/${SERVICE}/"
  if [[ ! -d "$SRC" ]]; then
    echo "ERROR: services/${SERVICE} not found in source (${REPO_ROOT})" >&2
    exit 1
  fi
  [[ ! -d "$DST" ]] && mkdir -p "$DST"

  RSYNC_OPTS=(-av --delete)
  [[ "$DRY_RUN" -eq 1 ]] && RSYNC_OPTS+=(--dry-run)

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
    echo "Re-run with --apply to apply."
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
  # user data (NEVER sync)
  --exclude='profiles/'
  --exclude='functions/'
  --exclude='test-profiles/'
  --exclude='.community/'
  --exclude='.claude/'
  --exclude='.state/'
  --exclude='.task/'
  --exclude='.timewarrior/'
  # dev-only
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
  --exclude='sync.sh'
)

# Conditionally exclude dev/ and docs/
[[ "$INCLUDE_DEV" -eq 0 ]]  && EXCLUDES+=(--exclude='dev/')
[[ "$INCLUDE_DOCS" -eq 0 ]] && EXCLUDES+=(--exclude='docs/')

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN — changes that would be applied to ${TARGET}:"
  echo "  from: ${REPO_ROOT}"
  echo "  to:   ${TARGET}"
  echo "(run with --apply to execute)"
  echo ""
fi

rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" "${REPO_ROOT}/" "${TARGET}/"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "Re-run with --apply to apply."
else
  echo ""
  echo "Sync complete: ${REPO_ROOT} → ${TARGET}"
fi
