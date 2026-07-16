# ww-popup-screens/ledger.sh — Ledger screen using hledger with correct double-entry format

screen_ledger() {
  popup_require_profile || return

  local ledger_file
  ledger_file="$(popup_ledger_file)"
  if [[ -z "$ledger_file" || ! -f "$ledger_file" ]]; then
    popup_notify "No ledger file found"
    return
  fi

  local ctx
  ctx="$(popup_context_bar)"

  local menu="💳  Log Transaction
💰  View Balances
📜  Recent Transactions
📊  Monthly Expenses"

  local choice
  choice=$(echo "$menu" | popup_select "💰 Ledger" "$ctx") || return

  case "$choice" in
    *"Log Transaction"*)
      _ledger_add_transaction "$ledger_file"
      screen_ledger; return
      ;;
    *"View Balances"*)
      _ledger_show_balances "$ledger_file"
      screen_ledger; return
      ;;
    *"Recent Transactions"*)
      _ledger_show_register "$ledger_file"
      screen_ledger; return
      ;;
    *"Monthly Expenses"*)
      _ledger_show_monthly "$ledger_file"
      screen_ledger; return
      ;;
    *)
      screen_ledger; return
      ;;
  esac
}

_ledger_add_transaction() {
  local ledger_file="$1"

  # Guided flow: amount → expense account → source account → description → confirm

  # 1. Amount
  local amount
  amount=$(popup_input "Amount (e.g., 5.50, 120.00)") || return
  [[ -z "$amount" ]] && return
  # Ensure dollar sign
  [[ "$amount" != '$'* ]] && amount="\$${amount}"

  # 2. Expense account (picker)
  local accounts account
  accounts=$(hledger -f "$ledger_file" accounts 2>/dev/null)
  if [[ -z "$accounts" ]]; then
    account=$(popup_input "Expense account (e.g., expenses:food)") || return
  else
    account=$(echo "$accounts" | popup_select "Expense account") || return
  fi
  [[ -z "$account" ]] && return

  # 3. Source account (picker)
  local source
  if [[ -n "$accounts" ]]; then
    source=$(echo "$accounts" | popup_select "Source account (pays from)") || return
  else
    source=$(popup_input "Source account (e.g., assets:checking)") || return
  fi
  [[ -z "$source" ]] && return

  # 4. Description
  local desc
  desc=$(popup_input "Description") || return
  [[ -z "$desc" ]] && desc="Transaction"

  # 5. Confirm
  local today
  today=$(date '+%Y-%m-%d')
  local preview="${today} ${desc}
    ${account}  ${amount}
    ${source}"

  popup_confirm "Log transaction?" "$preview" || return

  # Write the transaction — second posting has NO amount (hledger auto-balances)
  printf '\n%s %s\n    %s  %s\n    %s\n' \
    "$today" "$desc" "$account" "$amount" "$source" >> "$ledger_file"

  popup_notify "Transaction logged: ${amount} → ${account}"
}

_ledger_show_balances() {
  local ledger_file="$1"
  local output
  output=$(hledger -f "$ledger_file" balance --flat --no-total 2>/dev/null) || output="(no data)"
  popup_display "Balances" "" "$output" || true
}

_ledger_show_register() {
  local ledger_file="$1"
  local output
  output=$(hledger -f "$ledger_file" register -n 10 2>/dev/null) || output="(no transactions)"
  popup_display "Recent" "" "$output" || true
}

_ledger_show_monthly() {
  local ledger_file="$1"
  local output
  output=$(hledger -f "$ledger_file" balance expenses -p 'this month' 2>/dev/null) || output="(no expenses this month)"
  popup_display "This Month" "" "$output" || true
}
