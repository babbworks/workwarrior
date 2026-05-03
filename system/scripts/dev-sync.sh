#!/usr/bin/env bash
# system/scripts/dev-sync.sh — sync program files from repo to a ww instance
#
# Usage:
#   bash system/scripts/dev-sync.sh              # dry-run: show what would change
#   bash system/scripts/dev-sync.sh --apply      # apply: actually sync
#   bash system/scripts/dev-sync.sh --apply --target ~/ww   # sync to production
#
# Default target: ~/ww-dev  (development instance)
# Alt target:     ~/ww      (production instance — use with care)
#
# What is synced (program files only):
#   bin/          CLI dispatcher and helpers
#   lib/          Core bash libraries
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
#   tools/            installed extensions (warlock clone, etc.)
#   functions/        personal data
#   test-profiles/    bats test artifacts
#   tests/            dev-only test suite
#   system/           dev control plane (not shipped)
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
TARGET="${HOME}/ww-dev"
DRY_RUN=1

for arg in "$@"; do
  case "$arg" in
    --apply)       DRY_RUN=0 ;;
    --target)      shift; TARGET="$1" ;;
    --target=*)    TARGET="${arg#--target=}" ;;
    --help|-h)
      sed -n '2,/^set /p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

TARGET="${TARGET%/}"  # strip trailing slash

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: target directory does not exist: $TARGET" >&2
  exit 1
fi

RSYNC_OPTS=(-av --delete)
[[ "$DRY_RUN" -eq 1 ]] && RSYNC_OPTS+=(--dry-run)

EXCLUDES=(
  # user data
  --exclude='profiles/'
  --exclude='tools/'
  --exclude='functions/'
  --exclude='test-profiles/'
  --exclude='.community/'
  --exclude='.claude/'
  --exclude='.state/'
  --exclude='.task/'
  --exclude='.timewarrior/'
  # dev-only
  --exclude='tests/'
  --exclude='system/'
  --exclude='docs/'
  --exclude='stories/'
  --exclude='pending/'
  --exclude='devsystem/'
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
