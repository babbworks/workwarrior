#!/bin/bash
# Handler for ledger service - integrates with Hledger

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

# Check if profile is active
if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile active" >&2
    exit 1
fi

# Check if hledger is available
if ! command -v hledger &> /dev/null; then
    echo "Error: hledger command not found" >&2
    exit 1
fi

echo "Handler: ledger"
echo "Template: $template_file"
echo ""

# Get the default ledger file from ledgers.yaml
ledgers_config="$WORKWARRIOR_BASE/ledgers.yaml"
if [[ ! -f "$ledgers_config" ]]; then
    echo "Error: Ledgers configuration not found: $ledgers_config" >&2
    exit 1
fi

# Extract default ledger path
ledger_file=$(python3 -c "
import yaml
import sys
try:
    with open('$ledgers_config', 'r') as f:
        config = yaml.safe_load(f)
    ledgers = config.get('ledgers', {})
    # Get first ledger as default
    if ledgers:
        print(list(ledgers.values())[0])
    else:
        sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

if [[ -z "$ledger_file" ]]; then
    # Fallback to profile name
    profile_name=$(basename "$WORKWARRIOR_BASE")
    ledger_file="$WORKWARRIOR_BASE/ledgers/${profile_name}.journal"
fi

if [[ ! -f "$ledger_file" ]]; then
    echo "Warning: Ledger file not found, creating: $ledger_file"
    mkdir -p "$(dirname "$ledger_file")"
    touch "$ledger_file"
fi

echo "Ledger file: $ledger_file"
echo ""

# Extract answers and create ledger transaction
transaction=$(python3 -c "
import json
import sys
from datetime import datetime

try:
    with open('$answers_file', 'r') as f:
        data = json.load(f)

    with open('$template_file', 'r') as f:
        template = json.load(f)

    answers = data['answers']
    questions = {q['id']: q['text'] for q in template['questions']}

    # Extract transaction components from answers
    date = datetime.now().strftime('%Y-%m-%d')
    description = ''
    amount = ''
    from_account = 'expenses:unknown'
    to_account = 'assets:checking'
    notes = []

    for key, value in answers.items():
        question_text = questions.get(key, '').lower()

        if 'date' in question_text:
            # Try to use provided date
            date = value if value else date
        elif 'description' in question_text or 'what' in question_text or 'payee' in question_text:
            description = value
        elif 'amount' in question_text or 'how much' in question_text or 'price' in question_text or 'cost' in question_text:
            # Clean amount - remove currency symbols, keep numbers and decimal
            clean_amount = ''.join(c for c in value if c.isdigit() or c in '.-')
            if clean_amount:
                amount = clean_amount
        elif 'from' in question_text or 'source' in question_text or 'paid from' in question_text:
            to_account = value.replace(' ', ':').lower()
            if not to_account.startswith(('assets', 'liabilities', 'equity')):
                to_account = f'assets:{to_account}'
        elif 'to' in question_text or 'category' in question_text or 'expense' in question_text or 'account' in question_text:
            from_account = value.replace(' ', ':').lower()
            if not from_account.startswith(('expenses', 'income', 'assets', 'liabilities')):
                from_account = f'expenses:{from_account}'
        elif not description:
            description = value
        else:
            notes.append(f'{questions.get(key, key)}: {value}')

    if not description:
        description = 'Transaction from template'

    if not amount:
        amount = '0.00'

    # Build hledger transaction format
    # Date Description
    #     Account1    Amount
    #     Account2

    transaction_lines = [f'{date} {description}']

    # Add notes as comments
    for note in notes:
        transaction_lines.append(f'    ; {note}')

    # Add postings
    transaction_lines.append(f'    {from_account}    \${amount}')
    transaction_lines.append(f'    {to_account}')

    print('\\n'.join(transaction_lines))

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")

if [[ $? -ne 0 || -z "$transaction" ]]; then
    echo "Error: Failed to parse answers" >&2
    exit 1
fi

echo "Transaction:"
echo "============"
echo "$transaction"
echo ""

# Append transaction to ledger file
echo "" >> "$ledger_file"
echo "$transaction" >> "$ledger_file"

if [[ $? -eq 0 ]]; then
    echo "Transaction added successfully"
    echo ""

    # Validate the ledger
    if hledger -f "$ledger_file" check 2>/dev/null; then
        echo "Ledger validation: OK"
        echo ""
        echo "Recent transactions:"
        hledger -f "$ledger_file" register -n 5 2>/dev/null || true
    else
        echo "Warning: Ledger may have validation issues"
        echo "Run 'hledger -f $ledger_file check' to see details"
    fi

    exit 0
else
    echo "Error: Failed to write transaction" >&2
    exit 1
fi
