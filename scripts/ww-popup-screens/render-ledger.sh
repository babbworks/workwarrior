# ww-popup-screens/render-ledger.sh — Ledger screen renderer

render_ledger() {
  _init_profile
  local ledger_file
  ledger_file=$(profile_ledger_file)

  emit_prompt "💰 Ledger"
  emit_message "Type \$amount description to log expense"
  emit_data "ledger"
  emit_allow_custom
  emit_hotkeys

  if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
    emit_row "📊  Account Balances" "nav:ledger_balances"
    emit_row "📋  Recent Transactions" "nav:ledger_register"
    emit_row "💸  Monthly Expenses" "nav:ledger_monthly"
    emit_row "📈  Balance Sheet" "nav:ledger_balancesheet"
    emit_row "📉  Income Statement" "nav:ledger_incomestatement"
    emit_row "🔍  Search Transactions" "nav:ledger_search"
    emit_row "📝  Add Note/Comment" "nav:ledger_comment"
  else
    emit_label "(no ledger file configured)"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_ledger_balances() {
  _init_profile
  local ledger_file; ledger_file=$(profile_ledger_file)

  emit_prompt "Balances"
  emit_data "ledger"
  emit_hotkeys

  local output
  output=$(hledger -f "$ledger_file" balance --flat --no-total 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Account balances"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no data)"
  fi

  emit_sep
  emit_row "← Back" "nav:ledger"
}

render_ledger_register() {
  _init_profile
  local ledger_file; ledger_file=$(profile_ledger_file)

  emit_prompt "Register"
  emit_data "ledger"
  emit_hotkeys

  local output
  output=$(hledger -f "$ledger_file" register -n 15 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Recent transactions"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no transactions)"
  fi

  emit_sep
  emit_row "← Back" "nav:ledger"
}

render_ledger_monthly() {
  _init_profile
  local ledger_file; ledger_file=$(profile_ledger_file)

  emit_prompt "Monthly"
  emit_data "ledger"
  emit_hotkeys

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

  emit_sep
  emit_row "← Back" "nav:ledger"
}

render_ledger_search() {
  emit_prompt "Search ledger"
  emit_message "Type description to search"
  emit_data "ledger_search"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type query above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:ledger"
}

render_ledger_balancesheet() {
  _init_profile
  local ledger_file; ledger_file=$(profile_ledger_file)

  emit_prompt "Balance Sheet"
  emit_data "ledger"
  emit_hotkeys

  local output
  output=$(hledger -f "$ledger_file" balancesheet 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Balance sheet"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no data)"
  fi

  emit_sep
  emit_row "← Back" "nav:ledger"
}

render_ledger_incomestatement() {
  _init_profile
  local ledger_file; ledger_file=$(profile_ledger_file)

  emit_prompt "Income Statement"
  emit_data "ledger"
  emit_hotkeys

  local output
  output=$(hledger -f "$ledger_file" incomestatement 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Income statement"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no data)"
  fi

  emit_sep
  emit_row "← Back" "nav:ledger"
}

render_ledger_comment() {
  emit_prompt "Ledger Note"
  emit_message "Type a comment/annotation to add to the ledger"
  emit_data "ledger_comment"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type note above — will be added as a comment line)"
  emit_sep
  emit_row "← Back" "nav:ledger"
}
