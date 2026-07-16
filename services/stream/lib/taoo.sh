#!/usr/bin/env bash

taoo_classify() {
  local ts="${1:-}" op="${2:-}" action="${3:-}" obj="${4:-}" ctx="${5:-}"
  local actor
  actor=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('actor',''))" "$ctx" 2>/dev/null || echo "")
  printf "T=%s\tA=%s\tO=%s\tActor=%s\tOcc=%s\n" "$ts" "$action" "$obj" "$actor" "$ctx"
}

taoo_filter() {
  local pattern="$1"
  awk -v p="$pattern" '$3 ~ p'
}
