#!/usr/bin/env bash
# sync.sh — copy workwarrior code files from this repo into a target instance
# Does not touch profiles/, .git/, or shell configuration.
# Usage: ./sync.sh <target-path> [--dry-run] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""
DRY_RUN=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --help|-h)
      echo "Usage: $(basename "$0") <target-path> [--dry-run] [--force]"
      echo ""
      echo "Copies bin/, lib/, services/, scripts/, resources/, config/ from"
      echo "this checkout into <target-path>. Profiles and shell config are untouched."
      echo ""
      echo "Examples:"
      echo "  ./sync.sh ~/wwv02"
      echo "  ./sync.sh ~/ww-yupi --dry-run"
      echo "  ./sync.sh ~/wwv02 --force"
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg" >&2; exit 1 ;;
    *)
      TARGET="$arg" ;;
  esac
done

TARGET="${TARGET/#\~/$HOME}"

if [[ -z "$TARGET" ]]; then
  echo "Error: target path required" >&2
  echo "Usage: $(basename "$0") <target-path> [--dry-run] [--force]" >&2
  exit 1
fi
if [[ ! -d "$TARGET" ]]; then
  echo "Error: target not found: $TARGET" >&2
  exit 1
fi
if [[ "$SCRIPT_DIR" -ef "$TARGET" ]]; then
  echo "Error: source and target are the same directory" >&2
  exit 1
fi

DIRS=("bin" "lib" "services" "scripts" "resources" "config")
EXISTING=()
for d in "${DIRS[@]}"; do
  [[ -d "$SCRIPT_DIR/$d" ]] && EXISTING+=("$d")
done

echo ""
echo "Workwarrior Sync"
echo "  from: $SCRIPT_DIR"
echo "  to:   $TARGET"
echo "  dirs: ${EXISTING[*]}"
(( DRY_RUN )) && echo "  mode: DRY RUN"
echo ""

if (( ! FORCE && ! DRY_RUN )); then
  read -rp "Proceed? [y/n]: " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Cancelled"; exit 0; }
fi

COPIED=0
for d in "${EXISTING[@]}"; do
  if (( DRY_RUN )); then
    echo "  [dry-run] would copy $d/"
  else
    cp -r "$SCRIPT_DIR/$d/"* "$TARGET/$d/" 2>/dev/null || true
    chmod +x "$TARGET/bin/"* 2>/dev/null || true
    echo "  ok $d/"
    COPIED=$(( COPIED + 1 ))
  fi
done

if (( ! DRY_RUN )); then
  [[ -f "$SCRIPT_DIR/VERSION" ]] && cp "$SCRIPT_DIR/VERSION" "$TARGET/VERSION" && echo "  ok VERSION"
  echo ""
  echo "Sync complete ($COPIED dirs updated)"
  echo "If browser is running, restart it:"
  echo "  pkill -f server.py && python3 $TARGET/services/browser/server.py --ww-base $TARGET --port <port> &"
fi
