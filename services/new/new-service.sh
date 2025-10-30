#!/usr/bin/env bash
# Workwarrior "new service" creator

SERVICES_DIR="$HOME/ww/services"

# === Step 1: Basic metadata questions ===
read -p "Name of service: " SERVICE_NAME
read -p "Proposed shortname (alias): " SERVICE_SHORT
read -p "Description of the service: " SERVICE_DESC
read -p "Connections to Other Services?: " SERVICE_CONN
read -p "Coding Considerations?: " SERVICE_CODE

# Normalize shortname to lowercase for files
SERVICE_SHORT=$(echo "$SERVICE_SHORT" | tr '[:upper:]' '[:lower:]')
SERVICE_DIR="$SERVICES_DIR/$SERVICE_SHORT"
HELP_FILE="$SERVICE_DIR/${SERVICE_SHORT}-help.sh"

# === Step 2: Collect multiline arrays ===
function collect_multiline() {
  local prompt="$1"
  local result=()
  echo "$prompt (press Enter for new entry, Enter twice to finish):"
  while true; do
    read -r line
    if [[ -z "$line" ]]; then
      # Double Enter breaks
      if [[ "${#result[@]}" -eq 0 || -z "${result[-1]}" ]]; then
        break
      fi
    fi
    if [[ -n "$line" ]]; then
      result+=("$line")
    fi
  done
  echo "${result[@]}"
}

ACTIONS=($(collect_multiline "You can use it to"))
EXAMPLES=($(collect_multiline "Example usage inside Workwarrior"))
TIPS=($(collect_multiline "Tips"))


# === Step 3: Create service folder ===
mkdir -p "$SERVICE_DIR"

# === Step 4: Generate help file ===
cat > "$HELP_FILE" <<EOF
#!/usr/bin/env bash
# Auto-generated help file for Workwarrior service: $SERVICE_NAME

echo "========================================================="
echo "                   WORKWARRIOR ${SERVICE_NAME^^}"
echo "========================================================="
echo
echo "$SERVICE_DESC"
echo
echo "Connections to Other Services: $SERVICE_CONN"
echo "Coding Considerations: $SERVICE_CODE"
echo
echo "You can use it to:"
EOF

for action in "${ACTIONS[@]}"; do
  echo "echo \"  • $action\"" >> "$HELP_FILE"
done

cat >> "$HELP_FILE" <<EOF
echo
echo "Example usage inside Workwarrior:"
EOF

for example in "${EXAMPLES[@]}"; do
  echo "echo \"  $example\"" >> "$HELP_FILE"
done

cat >> "$HELP_FILE" <<EOF
echo
echo "Tips:"
EOF

for tip in "${TIPS[@]}"; do
  echo "echo \"  • $tip\"" >> "$HELP_FILE"
done

cat >> "$HELP_FILE" <<EOF
echo
echo "========================================================="
echo "End of ${SERVICE_NAME^^} Help"
EOF

chmod +x "$HELP_FILE"

echo
echo "✅ New service '$SERVICE_NAME' created at: $HELP_FILE"
echo "   Shortname alias suggestion: alias $SERVICE_SHORT='$HELP_FILE'"
