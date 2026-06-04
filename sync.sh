#!/usr/bin/env bash
# sync.sh — copy workwarrior code files from this repo into a target instance
# Does not touch profiles/, .git/, or shell configuration.
# Usage: ./sync.sh <target-path> [--service <name>] [--dry-run] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""
DRY_RUN=0
FORCE=0
SERVICE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --service)
      shift
      [[ $# -eq 0 ]] && { echo "Error: --service requires a name" >&2; exit 1; }
      SERVICE="$1"
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") <target-path> [--service <name>] [--dry-run] [--force]"
      echo ""
      echo "Copies bin/, lib/, services/, scripts/, resources/, config/ from"
      echo "this checkout into <target-path>. Profiles and shell config are untouched."
      echo ""
      echo "  --service <name>   Sync only services/<name>/ (e.g. browser, stream)"
      echo ""
      echo "Examples:"
      echo "  ./sync.sh ~/wwv02"
      echo "  ./sync.sh ~/wwv02 --service browser"
      echo "  ./sync.sh ~/wwv02 --service browser --force"
      echo "  ./sync.sh ~/ww-yupi --dry-run"
      echo "  ./sync.sh ~/wwv02 --force"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2; exit 1 ;;
    *)
      TARGET="$1" ;;
  esac
  shift
done

TARGET="${TARGET/#\~/$HOME}"

if [[ -z "$TARGET" ]]; then
  echo "Error: target path required" >&2
  echo "Usage: $(basename "$0") <target-path> [--service <name>] [--dry-run] [--force]" >&2
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

# ── Service-targeted sync ───────────────────────────────────────────────────
if [[ -n "$SERVICE" ]]; then
  SRC="$SCRIPT_DIR/services/$SERVICE"
  DST="$TARGET/services/$SERVICE"
  if [[ ! -d "$SRC" ]]; then
    echo "Error: services/$SERVICE not found in source" >&2; exit 1
  fi
  if [[ ! -d "$DST" ]]; then
    echo "Error: services/$SERVICE not found in target ($TARGET)" >&2; exit 1
  fi
  echo ""
  echo "Workwarrior Sync (service: $SERVICE)"
  echo "  from: $SRC"
  echo "  to:   $DST"
  (( DRY_RUN )) && echo "  mode: DRY RUN"
  echo ""
  if (( ! FORCE && ! DRY_RUN )); then
    read -rp "Proceed? [y/n]: " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Cancelled"; exit 0; }
  fi
  if (( DRY_RUN )); then
    echo "  [dry-run] would copy services/$SERVICE/"
  else
    cp -r "$SRC/"* "$DST/" 2>/dev/null || true
    echo "  ok services/$SERVICE/"
    echo ""
    echo "Sync complete (1 service updated)"
    if [[ "$SERVICE" == "browser" ]]; then
      echo "If browser is running, restart it:"
      echo "  pkill -f server.py && python3 $TARGET/services/browser/server.py --ww-base $TARGET --port <port> &"
    fi
  fi
  exit 0
fi

# ── Full sync ───────────────────────────────────────────────────────────────
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
