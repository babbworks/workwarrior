#!/usr/bin/env bash
# services/projects/projects.sh — ww projects: cross-resource project views
set -euo pipefail

show_help() {
  cat <<'EOF'
Projects — cross-resource project views (tasks · journals · ledgers · times)

Usage: ww projects [subcommand] [args]

Subcommands:
  list                   List all projects for active profile (default)
  show <name>            Show detail for a project
  describe <name> <text> Set project description in config/projects.yaml

Examples:
  ww projects
  ww projects list
  ww projects show api
  ww projects describe api "API service development"
EOF
}

_require_profile() {
  if [[ -z "${WARRIOR_PROFILE:-}" ]]; then
    echo "projects: no active profile — activate one with p-<name>" >&2
    exit 1
  fi
}

_projects_yaml() {
  echo "${WW_BASE:-$HOME/ww}/config/projects.yaml"
}

_get_description() {
  local name="$1" yaml
  yaml="$(_projects_yaml)"
  [[ -f "$yaml" ]] || return 0
  python3 - "$yaml" "$name" <<'PYEOF'
import sys, re
yaml_path, proj = sys.argv[1], sys.argv[2]
content = open(yaml_path).read()
in_proj = False
for line in content.splitlines():
    if re.match(rf'^  {re.escape(proj)}:\s*$', line):
        in_proj = True; continue
    if in_proj:
        m = re.match(r'^\s+description:\s*(.*)', line)
        if m: print(m.group(1).strip()); break
        if line and not line.startswith(' '): break
PYEOF
}

cmd_list() {
  _require_profile
  local projects
  projects=$(TASKRC="$TASKRC" TASKDATA="$TASKDATA" task _projects 2>/dev/null | sort) || true
  if [[ -z "$projects" ]]; then
    echo "No projects found in active profile ($WARRIOR_PROFILE)"
    return 0
  fi
  echo "Projects — $WARRIOR_PROFILE:"
  while IFS= read -r proj; do
    local count desc
    count=$(TASKRC="$TASKRC" TASKDATA="$TASKDATA" task project:"$proj" count 2>/dev/null || echo 0)
    desc=$(_get_description "$proj")
    if [[ -n "$desc" ]]; then
      printf "  %-30s %3s tasks  %s\n" "$proj" "$count" "$desc"
    else
      printf "  %-30s %3s tasks\n" "$proj" "$count"
    fi
  done <<< "$projects"
}

cmd_show() {
  local name="${1:-}"
  [[ -z "$name" ]] && { echo "projects show: name required" >&2; exit 1; }
  _require_profile
  local count desc
  count=$(TASKRC="$TASKRC" TASKDATA="$TASKDATA" task project:"$name" count 2>/dev/null || echo 0)
  desc=$(_get_description "$name")
  echo "Project: $name"
  [[ -n "$desc" ]] && echo "  Description: $desc"
  echo "  Tasks (pending): $count"
  echo ""
  TASKRC="$TASKRC" TASKDATA="$TASKDATA" task project:"$name" 2>/dev/null || true
}

cmd_describe() {
  local name="${1:-}" text="${2:-}"
  [[ -z "$name" || -z "$text" ]] && { echo "projects describe: name and text required" >&2; exit 1; }
  local yaml
  yaml="$(_projects_yaml)"
  python3 - "$yaml" "$name" "$text" <<'PYEOF'
import sys, re, os
yaml_path, proj, desc = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(yaml_path), exist_ok=True)
content = open(yaml_path).read() if os.path.isfile(yaml_path) else "projects:\n"
lines = content.splitlines(keepends=True)
# Find or insert project block
found_proj = False; found_desc = False; insert_at = None
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    if re.match(rf'^  {re.escape(proj)}:\s*$', line):
        found_proj = True
        new_lines.append(line)
        i += 1
        while i < len(lines) and lines[i].startswith('    '):
            if re.match(r'^\s+description:', lines[i]):
                new_lines.append(f'    description: {desc}\n')
                found_desc = True
            else:
                new_lines.append(lines[i])
            i += 1
        if not found_desc:
            new_lines.append(f'    description: {desc}\n')
            found_desc = True
        continue
    new_lines.append(line)
    i += 1
if not found_proj:
    if not new_lines or new_lines[-1].strip():
        new_lines.append('\n')
    new_lines.append(f'  {proj}:\n')
    new_lines.append(f'    description: {desc}\n')
with open(yaml_path, 'w') as f:
    f.writelines(new_lines)
print(f"Updated: {proj}")
PYEOF
}

main() {
  local sub="${1:-list}"
  shift 2>/dev/null || true
  case "$sub" in
    list)     cmd_list ;;
    show)     cmd_show "$@" ;;
    describe) cmd_describe "$@" ;;
    help|-h|--help) show_help ;;
    *)
      echo "projects: unknown subcommand '$sub'" >&2
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
