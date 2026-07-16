# ww-popup-screens/render-reports.sh — Reports screen renderer

render_reports() {
  _init_profile

  emit_prompt "📊 Reports"
  emit_message "Summary views"
  emit_data "reports"
  emit_hotkeys

  emit_row "🕐  Time Today" "nav:report_time_day"
  emit_row "📅  Time This Week" "nav:report_time_week"
  emit_row "✅  Tasks Completed (7d)" "nav:report_tasks_done"
  emit_row "💸  Spending This Month" "nav:report_spending"
  emit_sep
  emit_row "← Home" "nav:home"
}

render_report_time_day() {
  _init_profile
  local twdb; twdb="$(profile_twdb)"

  emit_prompt "Time Today"
  emit_data "reports"
  emit_hotkeys

  local output
  output=$(TIMEWARRIORDB="$twdb" timew summary :day 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no time tracked today)"
  fi
  emit_sep
  emit_row "← Back" "nav:reports"
}

render_report_time_week() {
  _init_profile
  local twdb; twdb="$(profile_twdb)"

  emit_prompt "Time This Week"
  emit_data "reports"
  emit_hotkeys

  local output
  output=$(TIMEWARRIORDB="$twdb" timew summary :week 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no time tracked this week)"
  fi
  emit_sep
  emit_row "← Back" "nav:reports"
}

render_report_tasks_done() {
  _init_profile
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"

  emit_prompt "Completed (7d)"
  emit_data "reports"
  emit_hotkeys

  local output
  output=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no rc.verbose=nothing \
    status:completed "end.after:today-7d" export 2>/dev/null | python3 -c '
import json, sys
try:
    tasks = json.load(sys.stdin)
except:
    sys.exit(0)
for t in tasks:
    desc = t.get("description", "")
    end = t.get("end", "")[:10] if t.get("end") else ""
    print(f"  {end}  {desc}")
' 2>/dev/null)

  if [[ -n "$output" ]]; then
    emit_message "Tasks completed in last 7 days"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no completions in last 7 days)"
  fi
  emit_sep
  emit_row "← Back" "nav:reports"
}

render_report_spending() {
  _init_profile
  local ledger_file; ledger_file=$(profile_ledger_file)

  emit_prompt "Spending"
  emit_data "reports"
  emit_hotkeys

  if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
    local output
    output=$(hledger -f "$ledger_file" balance expenses -p 'this month' 2>/dev/null)
    if [[ -n "$output" ]]; then
      emit_message "Expenses this month"
      while IFS= read -r line; do
        emit_label "$line"
      done <<< "$output"
    else
      emit_label "(no expenses this month)"
    fi
  else
    emit_label "(no ledger configured)"
  fi
  emit_sep
  emit_row "← Back" "nav:reports"
}
