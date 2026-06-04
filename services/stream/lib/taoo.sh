#!/usr/bin/env bash

taoo_classify() {
  local ts="${1:-}" op="${2:-}" action="${3:-}" obj="${4:-}" ctx="${5:-}"
  printf "T=%s\tA=%s\tO=%s\tOcc=%s\n" "$ts" "$action" "$obj" "$ctx"
}

taoo_filter() {
  local pattern="$1"
  awk -v p="$pattern" '$3 ~ p'
}
