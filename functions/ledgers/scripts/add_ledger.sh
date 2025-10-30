#!/bin/bash
PROFILE="$1"
if [[ -z "$PROFILE" ]]; then
  echo "Usage: $0 <profile-name>"
  exit 1
fi
BASE="$HOME/ww/profiles/$PROFILE"
LEDGERS="$BASE/ledgers"
LEDGER_CONFIG="$BASE/ledgers.yaml"
SHELL_RC="$HOME/.bashrc"

mkdir -p "$LEDGERS"

echo "Enter unique ledger name:"
read -r ledger_name
ledger_file="$LEDGERS/$ledger_name.journal"
cat > "$ledger_file" <<EOF
; Hledger journal for $PROFILE/$ledger_name
; Initialized on $(date '+%Y-%m-%d')
account assets:cash
account expenses:misc
account equity:opening-balances

$(date '+%Y-%m-%d') * Profile initialization
    assets:cash                 \$0.00
    equity:opening-balances    \$0.00
EOF

# Update ledgers.yaml
if ! grep -q "  $ledger_name:" "$LEDGER_CONFIG"; then
  sed -i "/^ledgers:/a\  $ledger_name: $ledger_file" "$LEDGER_CONFIG"
fi

# Add aliases
L_ALIAS="alias l-$ledger_name='hledger -f \"$ledger_file\"'"
L_ALIAS_LONG="alias l-$PROFILE-$ledger_name='hledger -f \"$ledger_file\"'"
if ! grep -Fxq "$L_ALIAS" "$SHELL_RC"; then
  echo "$L_ALIAS" >> "$SHELL_RC"
fi
if ! grep -Fxq "$L_ALIAS_LONG" "$SHELL_RC"; then
  echo "$L_ALIAS_LONG" >> "$SHELL_RC"
fi

echo "✓ Created ledger $ledger_name and updated config/aliases."
