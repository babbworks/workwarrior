#!/usr/bin/env bash

echo "📦 Scanning for installed Python versions..."

# Candidate paths to search
CANDIDATE_PATHS=(
  "/usr/local/bin/python*"
  "/opt/homebrew/bin/python*"
  "/usr/bin/python*"
  "$HOME/.pyenv/versions/*/bin/python*"
  "/Library/Frameworks/Python.framework/Versions/*/bin/python*"
)

# Expand and deduplicate actual matches
FOUND=()
for path in "${CANDIDATE_PATHS[@]}"; do
  for match in $(ls $path 2>/dev/null | grep -E 'python[0-9.]*$'); do
    [[ ! " ${FOUND[*]} " =~ " $match " ]] && FOUND+=("$match")
  done
done

# Sort and display results
if [[ ${#FOUND[@]} -eq 0 ]]; then
  echo "❌ No Python binaries found."
  exit 1
fi

echo
printf "%-10s %-10s %s\n" "Version" "Origin" "Path"
printf "%-10s %-10s %s\n" "-------" "------" "----"

for path in "${FOUND[@]}"; do
  ver=$("$path" --version 2>/dev/null | awk '{print $2}')
  origin=""
  case "$path" in
    /usr/local/bin/*) origin="homebrew" ;;
    /opt/homebrew/bin/*) origin="homebrew" ;;
    /Library/Frameworks/*) origin="python.org" ;;
    $HOME/.pyenv/*) origin="pyenv" ;;
    /usr/bin/*) origin="system" ;;
    *) origin="unknown" ;;
  esac
  printf "%-10s %-10s %s\n" "$ver" "$origin" "$path"
done
