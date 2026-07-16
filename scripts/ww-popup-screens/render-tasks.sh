# ww-popup-screens/render-tasks.sh — Tasks screen renderer (rofi-script mode)

render_tasks() {
  _init_profile
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"

  local ctx; ctx="$(build_context_bar)"

  emit_prompt "📋 Tasks"
  emit_message "${ctx}  |  Alt+W:done  Alt+E:edit  Alt+T:timer"
  emit_data "tasks"
  emit_allow_custom
  emit_hotkeys

  # Get pending tasks sorted by urgency
  local task_lines
  task_lines=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no rc.verbose=nothing \
    status:pending export 2>/dev/null | python3 -c '
import json, sys
try:
    tasks = json.load(sys.stdin)
except:
    sys.exit(0)
tasks.sort(key=lambda t: t.get("urgency", 0), reverse=True)
for t in tasks[:25]:
    tid = t.get("id", 0)
    desc = t.get("description", "")
    proj = t.get("project", "")
    pri = t.get("priority", "")
    due = t.get("due", "")[:10] if t.get("due") else ""
    tags = ",".join(t.get("tags", []))
    # Build display
    parts = [f"{tid:3d}  {desc}"]
    meta = []
    if proj: meta.append(proj)
    if pri: meta.append(f"P:{pri}")
    if due: meta.append(f"D:{due}")
    if tags: meta.append(f"#{tags}")
    if meta: parts.append(" [" + " ".join(meta) + "]")
    display = "".join(parts)
    # Search terms
    search = f"{desc} {proj} {tags}"
    # Determine if urgent
    is_overdue = "due" in t and t.get("urgency", 0) > 10
    prefix = "U|" if is_overdue else ""
    print(f"{prefix}{tid}|{display}|{search}")
' 2>/dev/null)

  # Add task option
  emit_row "➕  Add Task" "nav:task_add" "add new task"

  if [[ -n "$task_lines" ]]; then
    emit_sep
    while IFS='|' read -r urgent_or_id rest_or_display search; do
      if [[ "$urgent_or_id" == "U" ]]; then
        # Overdue task
        local tid="$rest_or_display"
        IFS='|' read -r _ tid display search <<< "${urgent_or_id}|${rest_or_display}|${search}"
        tid="${rest_or_display%%|*}"
        display="${rest_or_display#*|}"
        emit_row_urgent "$display" "pick:task:${tid}" "$search"
      else
        # Normal task
        local tid="$urgent_or_id"
        emit_row "$rest_or_display" "pick:task:${tid}" "$search"
      fi
    done <<< "$task_lines"
  else
    emit_sep
    emit_label "(no pending tasks)"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_task_action() {
  local task_id="$1"
  _task_detail "$task_id" ""
}

render_task_post_add() {
  local task_id="$1"
  _task_detail "$task_id" "created"
}

_task_detail() {
  local task_id="$1" mode="$2"
  _init_profile
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"

  # Get full task fields using a reliable single-field-per-line approach
  local task_data
  task_data=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" export 2>/dev/null | python3 -c '
import json, sys
try:
    t = json.load(sys.stdin)[0]
except:
    sys.exit(0)
print(t.get("description", ""))
print(t.get("project", ""))
print(t.get("priority", ""))
print(t.get("due", "")[:10] if t.get("due") else "")
print(",".join(t.get("tags", [])))
print(t.get("wait", "")[:10] if t.get("wait") else "")
print(t.get("scheduled", "")[:10] if t.get("scheduled") else "")
print(len(t.get("annotations", [])))
print(t.get("status", "pending"))
' 2>/dev/null)

  local desc proj pri due tags wait sched ann_count status
  { read -r desc; read -r proj; read -r pri; read -r due; read -r tags; read -r wait; read -r sched; read -r ann_count; read -r status; } <<< "$task_data"

  local title="Task #${task_id}"
  [[ "$mode" == "created" ]] && title="✅ Created #${task_id}"

  emit_prompt "$title"
  emit_message "${desc}"
  emit_data "task_detail:${task_id}"
  emit_hotkeys

  # Post-add extras
  if [[ "$mode" == "created" ]]; then
    emit_row "✓  Done — back to tasks" "nav:tasks"
    emit_row "➕  Add another task" "nav:task_add"
    emit_sep
  fi

  # Quick actions
  emit_row "✅  Complete" "act:task_done:${task_id}"
  emit_row "▶️  Start Timer" "act:task_start_timer:${task_id}"
  emit_sep

  # Full field display — current values shown, select to change
  emit_label "Fields (select to edit):"
  emit_row "  Description:  ${desc:-—}" "nav:task_description:${task_id}"
  emit_row "  Project:      ${proj:-—}" "nav:task_project:${task_id}"
  emit_row "  Priority:     ${pri:-—}" "nav:task_priority:${task_id}"
  emit_row "  Due:          ${due:-—}" "nav:task_due:${task_id}"
  emit_row "  Tags:         ${tags:-—}" "nav:task_tags:${task_id}"
  emit_row "  Wait:         ${wait:-—}" "nav:task_wait:${task_id}"
  emit_row "  Scheduled:    ${sched:-—}" "nav:task_wait:${task_id}"
  emit_row "  Notes:        ${ann_count} annotation(s)" "nav:task_annotations:${task_id}"
  emit_row "  UDAs:         ..." "nav:task_uda:${task_id}"

  emit_sep
  emit_row "⏭️  Defer +1d" "act:task_defer_1d:${task_id}"
  emit_row "⏭️  Defer +1w" "act:task_defer_1w:${task_id}"
  emit_row "❌  Delete" "act:task_delete:${task_id}"

  if [[ "$mode" != "created" ]]; then
    emit_sep
    emit_row "← Back to Tasks" "nav:tasks"
  fi
}

# Sub-screens for task actions that need input

render_task_annotate() {
  local task_id="$1"
  emit_prompt "Note #${task_id}"
  emit_message "Type a note and press Enter"
  emit_data "task_annotate:${task_id}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type your note above)"
  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_notes() {
  local task_id="$1"
  _init_profile
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"

  emit_prompt "Notes #${task_id}"
  emit_data "task_action:${task_id}"
  emit_hotkeys

  local notes
  notes=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" export 2>/dev/null | python3 -c '
import json, sys
try:
    t = json.load(sys.stdin)[0]
    for a in t.get("annotations", []):
        date = a.get("entry","")[:16].replace("T"," ")
        print(f"{date}  {a.get(\"description\",\"\")}")
except:
    pass
' 2>/dev/null)

  if [[ -n "$notes" ]]; then
    emit_message "Annotations for task #${task_id}"
    while IFS= read -r line; do
      emit_label "  $line"
    done <<< "$notes"
  else
    emit_message "No notes"
    emit_label "(no annotations)"
  fi

  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_project() {
  local task_id="$1"
  _init_profile
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"

  emit_prompt "Project"
  emit_message "Select project for task #${task_id} (or type new)"
  emit_data "task_project:${task_id}"
  emit_allow_custom
  emit_hotkeys

  emit_row "(clear project)" "act:task_set_project:${task_id}|"
  local projects
  projects=$(TASKRC="$rc" TASKDATA="$data" task _unique project 2>/dev/null | grep -v '^$')
  if [[ -n "$projects" ]]; then
    while IFS= read -r proj; do
      emit_row "$proj" "act:task_set_project:${task_id}|${proj}"
    done <<< "$projects"
  fi
  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_priority() {
  local task_id="$1"

  emit_prompt "Priority"
  emit_message "Set priority for task #${task_id}"
  emit_data "task_priority:${task_id}"
  emit_hotkeys

  emit_row "H — High" "act:task_set_priority:${task_id}|H"
  emit_row "M — Medium" "act:task_set_priority:${task_id}|M"
  emit_row "L — Low" "act:task_set_priority:${task_id}|L"
  emit_row "(clear)" "act:task_set_priority:${task_id}|"
  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_due() {
  local task_id="$1"

  emit_prompt "Due date"
  emit_message "Type due date: tomorrow, friday, +3d, 2026-07-20, eow, eom"
  emit_data "task_due:${task_id}"
  emit_allow_custom
  emit_hotkeys

  emit_row "tomorrow" "act:task_set_due:${task_id}|tomorrow"
  emit_row "+3d" "act:task_set_due:${task_id}|+3d"
  emit_row "friday" "act:task_set_due:${task_id}|friday"
  emit_row "eow (end of week)" "act:task_set_due:${task_id}|eow"
  emit_row "eom (end of month)" "act:task_set_due:${task_id}|eom"
  emit_row "(clear due date)" "act:task_set_due:${task_id}|"
  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_tags() {
  local task_id="$1"
  _init_profile
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"

  emit_prompt "Tags #${task_id}"
  emit_message "Type +tag to add, or select existing to remove"
  emit_data "task_tags:${task_id}"
  emit_allow_custom
  emit_hotkeys

  # Show current tags on this task
  local current_tags
  current_tags=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" export 2>/dev/null | \
    python3 -c "import json,sys;[print(t) for t in json.load(sys.stdin)[0].get('tags',[])]" 2>/dev/null)

  if [[ -n "$current_tags" ]]; then
    emit_label "Current tags (select to remove):"
    while IFS= read -r tag; do
      emit_row "  -${tag}" "act:task_remove_tag:${task_id}|${tag}"
    done <<< "$current_tags"
    emit_sep
  fi

  # Show all available tags for adding
  local all_tags
  all_tags=$(TASKRC="$rc" TASKDATA="$data" task _unique tags 2>/dev/null | tr ',' '\n' | grep -v '^$')
  if [[ -n "$all_tags" ]]; then
    emit_label "Add tag:"
    while IFS= read -r tag; do
      emit_row "  +${tag}" "act:task_add_tag:${task_id}|${tag}"
    done <<< "$all_tags"
  fi

  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_add() {
  emit_prompt "New task"
  emit_message "Type task description (or: desc project:X priority:H due:tomorrow +tag)"
  emit_data "task_add"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type description above and press Enter)"
  emit_sep
  emit_row "← Back to Tasks" "nav:tasks"
}

render_task_description() {
  local task_id="$1"
  _init_profile
  local rc data; rc="$(profile_taskrc)"; data="$(profile_taskdata)"

  local current_desc
  current_desc=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" export 2>/dev/null | \
    python3 -c "import json,sys;print(json.load(sys.stdin)[0].get('description',''))" 2>/dev/null)

  emit_prompt "Description"
  emit_message "Current: ${current_desc}"
  emit_data "task_description:${task_id}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type new description above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_wait() {
  local task_id="$1"

  emit_prompt "Wait/Schedule"
  emit_message "Set wait (hidden until date) or scheduled date for task #${task_id}"
  emit_data "task_wait:${task_id}"
  emit_allow_custom
  emit_hotkeys

  emit_row "wait:tomorrow" "act:task_set_wait:${task_id}|tomorrow"
  emit_row "wait:+3d" "act:task_set_wait:${task_id}|+3d"
  emit_row "wait:+1w" "act:task_set_wait:${task_id}|+1w"
  emit_row "wait:eow" "act:task_set_wait:${task_id}|eow"
  emit_row "wait:eom" "act:task_set_wait:${task_id}|eom"
  emit_row "(clear wait)" "act:task_set_wait:${task_id}|"
  emit_sep
  emit_row "scheduled:tomorrow" "act:task_set_scheduled:${task_id}|tomorrow"
  emit_row "scheduled:+3d" "act:task_set_scheduled:${task_id}|+3d"
  emit_row "scheduled:monday" "act:task_set_scheduled:${task_id}|monday"
  emit_row "(clear scheduled)" "act:task_set_scheduled:${task_id}|"
  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_uda() {
  local task_id="$1"
  _init_profile
  local rc; rc="$(profile_taskrc)"

  emit_prompt "UDA #${task_id}"
  emit_message "Select UDA field to edit"
  emit_data "task_uda:${task_id}"
  emit_hotkeys

  # Get UDA names from .taskrc
  local udas
  udas=$(grep "^uda\." "$rc" 2>/dev/null | sed 's/^uda\.\([^.]*\)\..*/\1/' | sort -u)
  if [[ -n "$udas" ]]; then
    while IFS= read -r uda_name; do
      [[ -n "$uda_name" ]] && emit_row "  ${uda_name}" "nav:task_uda_edit:${task_id}|${uda_name}"
    done <<< "$udas"
  else
    emit_label "(no UDAs defined in this profile)"
  fi

  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}

render_task_uda_edit() {
  local args="$1"
  local task_id="${args%%|*}"
  local uda_name="${args#*|}"
  _init_profile
  local rc data; rc="$(profile_taskrc)"; data="$(profile_taskdata)"

  # Get current value
  local current_val
  current_val=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" export 2>/dev/null | \
    python3 -c "import json,sys;print(json.load(sys.stdin)[0].get('$uda_name',''))" 2>/dev/null)

  emit_prompt "${uda_name}"
  emit_message "Current value: ${current_val:-(empty)}  |  Type new value (empty to clear)"
  emit_data "task_uda_edit:${task_id}|${uda_name}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type value above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:task_uda:${task_id}"
}

render_task_annotations() {
  local task_id="$1"
  _init_profile
  local rc data; rc="$(profile_taskrc)"; data="$(profile_taskdata)"

  emit_prompt "Notes #${task_id}"
  emit_message "Select to delete, or type to add new"
  emit_data "task_annotations:${task_id}"
  emit_allow_custom
  emit_hotkeys

  local notes
  notes=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$task_id" export 2>/dev/null | python3 -c '
import json, sys
try:
    t = json.load(sys.stdin)[0]
    for a in t.get("annotations", []):
        date = a.get("entry","")[:16].replace("T"," ")
        desc = a.get("description","")
        print(f"{date}|{desc}")
except:
    pass
' 2>/dev/null)

  if [[ -n "$notes" ]]; then
    emit_label "Select note to remove:"
    while IFS='|' read -r date desc; do
      emit_row "  ${date}  ${desc}" "act:task_denotate:${task_id}|${desc}"
    done <<< "$notes"
  else
    emit_label "(no annotations — type above to add)"
  fi

  emit_sep
  emit_row "← Back" "nav:task_action:${task_id}"
}
