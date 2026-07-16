# ww-popup-screens/reports.sh — Reports screen (display-only)

screen_reports() {
  popup_require_profile || return

  local ctx
  ctx="$(popup_context_bar)"

  local menu="⏱️  Time Today
📅  Time This Week
✅  Tasks Completed (7d)
💰  Spending This Month"

  local choice
  choice=$(echo "$menu" | popup_select "📊 Reports" "$ctx") || return

  local base rc data ledger_file
  base="$(popup_profile_base)"
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  ledger_file="$(popup_ledger_file)"
  local twdb="${base}/.timewarrior"

  case "$choice" in
    *"Time Today"*)
      local output
      output=$(TIMEWARRIORDB="$twdb" timew summary :day 2>/dev/null) || output="(no data)"
      popup_display "Time Today" "" "$output" || true
      screen_reports; return
      ;;
    *"Time This Week"*)
      local output
      output=$(TIMEWARRIORDB="$twdb" timew summary :week 2>/dev/null) || output="(no data)"
      popup_display "Time This Week" "" "$output" || true
      screen_reports; return
      ;;
    *"Tasks Completed"*)
      local output
      output=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no status:completed "end.after:today-7d" export 2>/dev/null | python3 -c "
import json, sys
try:
    tasks = json.load(sys.stdin)
    if not tasks:
        print('(no tasks completed this week)')
    else:
        print(f'{len(tasks)} tasks completed in last 7 days:')
        print()
        for t in tasks:
            end = t.get('end','')[:10]
            print(f'  {end}  {t.get(\"description\",\"\")}')
except:
    print('(no data)')
" 2>/dev/null)
      popup_display "Completed (7d)" "" "$output" || true
      screen_reports; return
      ;;
    *"Spending"*)
      if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
        local output
        output=$(hledger -f "$ledger_file" balance expenses -p 'this month' 2>/dev/null) || output="(no data)"
        popup_display "Spending This Month" "" "$output" || true
      else
        popup_notify "No ledger file found"
      fi
      screen_reports; return
      ;;
    *)
      screen_reports; return
      ;;
  esac
}
