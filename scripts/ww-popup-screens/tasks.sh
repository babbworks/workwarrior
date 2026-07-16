# ww-popup-screens/tasks.sh — Tasks screen with full JSON export + action menu

screen_tasks() {
  popup_require_profile || return

  local rc data base
  base="$(popup_profile_base)"
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"

  # Get all pending tasks as JSON, parse with python3
  local task_lines
  task_lines=$(popup_task_export_all | python3 -c "
import json, sys
try:
    tasks = json.load(sys.stdin)
except:
    sys.exit(0)
tasks.sort(key=lambda t: t.get('urgency', 0), reverse=True)
for t in tasks[:30]:
    tid = t.get('id', '?')
    desc = t.get('description', '')
    proj = t.get('project', '')
    pri = t.get('priority', '')
    due = t.get('due', '')[:10] if t.get('due') else ''
    ann_count = len(t.get('annotations', []))
    tags = ','.join(t.get('tags', []))
    parts = [f'{tid}: {desc}']
    meta = []
    if proj: meta.append(proj)
    if pri: meta.append(f'P:{pri}')
    if due: meta.append(f'D:{due}')
    if tags: meta.append(f'#{tags}')
    if ann_count: meta.append(f'{ann_count}n')
    if meta: parts.append(' [' + ' '.join(meta) + ']')
    print(''.join(parts))
" 2>/dev/null)

  local ctx
  ctx="$(popup_context_bar)"

  local menu_items
  menu_items="➕  Add Task"
  if [[ -n "$task_lines" ]]; then
    menu_items="${menu_items}
${SEP}
${task_lines}"
  fi

  local choice
  choice=$(echo "$menu_items" | popup_select "Tasks" "$ctx") || return

  popup_is_sep "$choice" && { screen_tasks; return; }

  case "$choice" in
    *"Add Task"*)
      _tasks_add_flow
      screen_tasks; return
      ;;
    *)
      # Extract task ID from selection (first token before ":")
      local task_id
      task_id=$(echo "$choice" | grep -oE '^[0-9]+' | head -1)
      if [[ -n "$task_id" ]]; then
        _tasks_action_menu "$task_id"
      fi
      screen_tasks; return
      ;;
  esac
}

_tasks_action_menu() {
  local task_id="$1"

  # Get full task info via JSON
  local task_json task_info
  task_json=$(popup_task_export "$task_id")
  task_info=$(echo "$task_json" | python3 -c "
import json, sys
try:
    tasks = json.load(sys.stdin)
    t = tasks[0]
except:
    sys.exit(0)
desc = t.get('description', '')
proj = t.get('project', '-')
pri = t.get('priority', '-')
due = t.get('due', '')[:10] if t.get('due') else '-'
tags = ', '.join(t.get('tags', [])) or '-'
annotations = t.get('annotations', [])
ann_text = ''
if annotations:
    ann_text = '\\nNotes: ' + '; '.join([a.get('description','') for a in annotations[-3:]])
    if len(annotations) > 3:
        ann_text += f' (+{len(annotations)-3} more)'
status = t.get('status', '')
print(f'{desc}\\nProject: {proj} | Priority: {pri} | Due: {due}\\nTags: {tags}{ann_text}\\nStatus: {status}')
" 2>/dev/null)

  # Check if task is active (started)
  local is_active
  is_active=$(echo "$task_json" | python3 -c "
import json, sys
try:
    t = json.load(sys.stdin)[0]
    print('yes' if t.get('start') else 'no')
except:
    print('no')
" 2>/dev/null)

  local actions="✅  Complete
▶️  Start Timer
⏹️  Stop Task
📝  Add Note
📖  View Notes
📁  Set Project
🔴  Set Priority
📅  Set Due Date
🏷️  Add Tags
🗑️  Remove Tags
⚙️  Edit UDA
⏭️  Defer +1d
⏭️  Defer +1w
❌  Delete"

  local choice
  choice=$(echo "$actions" | popup_select "Task #${task_id}" "$task_info") || return

  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"

  case "$choice" in
    *"Complete"*)
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" done 2>/dev/null
      popup_notify "Task #${task_id} completed"
      ;;
    *"Start Timer"*)
      local desc
      desc=$(echo "$task_json" | python3 -c "import json,sys; print(json.load(sys.stdin)[0].get('description',''))" 2>/dev/null)
      local base
      base="$(popup_profile_base)"
      TIMEWARRIORDB="${base}/.timewarrior" timew start "$desc" 2>/dev/null
      popup_add_recent "$desc"
      popup_notify "Tracking: $desc"
      ;;
    *"Stop Task"*)
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" stop 2>/dev/null
      popup_notify "Task #${task_id} stopped"
      ;;
    *"Add Note"*)
      local note
      note=$(popup_input "Note for #${task_id}") || return
      [[ -z "$note" ]] && return
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" annotate "$note" 2>/dev/null
      popup_notify "Note added to #${task_id}"
      ;;
    *"View Notes"*)
      local notes
      notes=$(echo "$task_json" | python3 -c "
import json, sys
try:
    t = json.load(sys.stdin)[0]
    for a in t.get('annotations', []):
        date = a.get('entry','')[:16].replace('T',' ')
        print(f'{date}  {a.get(\"description\",\"\")}')
except:
    pass
" 2>/dev/null)
      if [[ -n "$notes" ]]; then
        popup_display "Notes #${task_id}" "" "$notes" || true
      else
        popup_notify "No notes on task #${task_id}"
      fi
      ;;
    *"Set Project"*)
      local projects project
      projects=$(popup_get_projects)
      project=$(echo "$projects" | popup_select "Project") || return
      [[ -z "$project" ]] && return
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "project:${project}" 2>/dev/null
      popup_notify "Project set: $project"
      ;;
    *"Set Priority"*)
      local pri
      pri=$(printf "H (High)\nM (Medium)\nL (Low)\n(none)" | popup_select "Priority") || return
      case "$pri" in
        *"H"*) TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify priority:H 2>/dev/null ;;
        *"M"*) TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify priority:M 2>/dev/null ;;
        *"L"*) TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify priority:L 2>/dev/null ;;
        *"none"*) TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify priority: 2>/dev/null ;;
      esac
      popup_notify "Priority updated"
      ;;
    *"Set Due"*)
      local due
      due=$(popup_input "Due date (tomorrow, friday, 2026-07-20, +3d)") || return
      [[ -z "$due" ]] && return
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "due:${due}" 2>/dev/null
      popup_notify "Due date set: $due"
      ;;
    *"Add Tags"*)
      local tag
      tag=$(popup_input "Tag to add (no # prefix)") || return
      [[ -z "$tag" ]] && return
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "+${tag}" 2>/dev/null
      popup_notify "Tag added: +${tag}"
      ;;
    *"Remove Tags"*)
      local current_tags tag
      current_tags=$(echo "$task_json" | python3 -c "
import json, sys
try:
    for t in json.load(sys.stdin)[0].get('tags', []):
        print(t)
except:
    pass
" 2>/dev/null)
      [[ -z "$current_tags" ]] && { popup_notify "No tags to remove"; return; }
      tag=$(echo "$current_tags" | popup_select "Remove tag") || return
      [[ -z "$tag" ]] && return
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "-${tag}" 2>/dev/null
      popup_notify "Tag removed: -${tag}"
      ;;
    *"Edit UDA"*)
      _tasks_edit_uda "$task_id"
      ;;
    *"+1d"*)
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "wait:+1d" 2>/dev/null
      popup_notify "Task deferred +1 day"
      ;;
    *"+1w"*)
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "wait:+1w" 2>/dev/null
      popup_notify "Task deferred +1 week"
      ;;
    *"Delete"*)
      popup_confirm "Delete task #${task_id}?" "This cannot be undone" || return
      TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" delete 2>/dev/null
      popup_notify "Task #${task_id} deleted"
      ;;
  esac
}

_tasks_edit_uda() {
  local task_id="$1"
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"

  local udas
  udas=$(popup_get_uda_names)
  [[ -z "$udas" ]] && { popup_notify "No UDAs defined"; return; }

  local uda_name
  uda_name=$(echo "$udas" | popup_select "UDA field") || return
  [[ -z "$uda_name" ]] && return

  local value
  value=$(popup_input "Value for ${uda_name} (empty to clear)") || return
  TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" modify "${uda_name}:${value}" 2>/dev/null
  popup_notify "UDA ${uda_name} updated"
}

_tasks_add_flow() {
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"

  # Description (required)
  local desc
  desc=$(popup_input "Task description") || return
  [[ -z "$desc" ]] && return

  # Optional: project
  local project="" projects
  projects=$(popup_get_projects)
  if [[ -n "$projects" ]]; then
    project=$(printf "(skip)\n%s" "$projects" | popup_select "Project (optional)") || project=""
    [[ "$project" == "(skip)" ]] && project=""
  fi

  # Optional: priority
  local priority=""
  priority=$(printf "(skip)\nH (High)\nM (Medium)\nL (Low)" | popup_select "Priority (optional)") || priority=""
  case "$priority" in
    *"H"*) priority="H" ;;
    *"M"*) priority="M" ;;
    *"L"*) priority="L" ;;
    *) priority="" ;;
  esac

  # Optional: due date
  local due=""
  due=$(popup_input "Due date (optional — tomorrow, +3d, 2026-07-20)") || due=""

  # Optional: tags
  local tags=""
  tags=$(popup_input "Tags (optional — space-separated, no #)") || tags=""

  # Build command
  local cmd_args=("$desc")
  [[ -n "$project" ]] && cmd_args+=("project:${project}")
  [[ -n "$priority" ]] && cmd_args+=("priority:${priority}")
  [[ -n "$due" ]] && cmd_args+=("due:${due}")
  if [[ -n "$tags" ]]; then
    for t in $tags; do
      cmd_args+=("+${t}")
    done
  fi

  TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no add "${cmd_args[@]}" 2>/dev/null
  popup_notify "Task added: $desc"
}
