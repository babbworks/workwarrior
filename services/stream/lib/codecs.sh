#!/usr/bin/env bash

codec_json() {
  python3 -c "
import sys, json
lines = [l for l in sys.stdin.read().splitlines() if l.strip()]
rows = []
for l in lines:
    parts = l.split(None, 4)
    rows.append(parts)
print(json.dumps(rows, indent=2))
"
}

codec_text() { cat; }
codec_ascii() { cat; }
