#!/usr/bin/env bash
set -e

HELP_DIR="$HOME/ww/services/help/primary"

echo "===================================================="
echo "   Workwarrior Help System Installer"
echo "===================================================="
echo "This will prepare your help scripts by setting them"
echo "as executables and adding aliases into ~/.bashrc."
echo
echo "The following scripts were found:"
ls -1 "$HELP_DIR"
echo
read -p "Do you want to make ALL of these executable? (y/n) " ans

if [[ "$ans" =~ ^[Yy]$ ]]; then
  chmod +x "$HELP_DIR"/*.sh
  echo "✔ All help scripts made executable."
else
  echo "Skipping mass chmod. You can run manually:"
  echo "  chmod +x $HELP_DIR/<file>.sh"
fi

echo
read -p "Do you want to add aliases to ~/.bashrc now? (y/n) " ans2
if [[ "$ans2" =~ ^[Yy]$ ]]; then
  {
    echo ""
    echo "# --- Workwarrior Help Aliases ---"
    echo "alias h=\"$HELP_DIR/menu.sh\""
    echo "alias who=\"$HELP_DIR/who.sh\""
    echo "alias what=\"$HELP_DIR/what.sh\""
    echo "alias where=\"$HELP_DIR/where.sh\""
    echo "alias why=\"$HELP_DIR/why.sh\""
    echo "alias when=\"$HELP_DIR/when.sh\""
    echo "alias how=\"$HELP_DIR/how.sh\""
  } >> "$HOME/.bashrc"
  echo "✔ Aliases added. Run 'source ~/.bashrc' to load them."
else
  echo "Skipping alias installation."
fi

echo
echo "Installation complete!"
