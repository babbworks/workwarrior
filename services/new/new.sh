#!/usr/bin/env bash
# Workwarrior - New Service Generator with Metadata

WW_HOME="$HOME/ww"
SERVICES_DIR="$WW_HOME/services"

AUTHOR="${USER}"

read -p "Service Name (full descriptive): " svc_name
read -p "Shortname (alias for bashrc/functions): " svc_short
read -p "Description: " svc_desc
read -p "Connections to Other Services?: " svc_conn
read -p "Coding Considerations?: " svc_code
read -p "Version (e.g., 0.1.0): " svc_version

# Create folder
svc_folder="$SERVICES_DIR/$svc_short"
mkdir -p "$svc_folder"

echo
echo "Enter the following sections. Press Enter twice to move to the next section."
echo

# Helper function for multi-line input
read_multiline() {
    local prompt="$1"
    local lines=()
    local line
    echo "$prompt"
    while true; do
        read -r line
        [[ -z "$line" && ${#lines[@]} -gt 0 ]] && break
        [[ -n "$line" ]] && lines+=("$line")
    done
    printf "%s\n" "${lines[@]}"
}

template_usage=$(read_multiline "You can use it to:")
template_example=$(read_multiline "Example usage inside Workwarrior:")
template_tips=$(read_multiline "Tips:")

# Create main service script
svc_script="$svc_folder/$svc_short.sh"
cat > "$svc_script" <<EOF
#!/usr/bin/env bash
# ========================================================
# WORKWARRIOR SERVICE
# Name: $svc_name
# Shortname: $svc_short
# Author: $AUTHOR
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Version: $svc_version
# Description: $svc_desc
# Connections: $svc_conn
# Coding Considerations: $svc_code
# ========================================================

echo "========================================================="
echo "                   WORKWARRIOR $svc_name"
echo "========================================================="
echo
echo "$svc_desc"
echo
echo "Connections: $svc_conn"
echo "Coding considerations: $svc_code"
echo
echo "You can use it to:"
echo "$template_usage"
echo
echo "Example usage inside Workwarrior:"
echo "$template_example"
echo
echo "Tips:"
echo "$template_tips"
echo
echo "========================================================="
read -p "Press Enter to return..."
EOF

chmod +x "$svc_script"

# Add function to .wwrc dynamically if missing
WW_RC="$WW_HOME/.wwrc"
func_entry="
$svc_short() {
    \"$svc_script\" \"\$@\"
}"
if ! grep -q "^$svc_short()" "$WW_RC"; then
    echo "$func_entry" >> "$WW_RC"
fi

# Symlink in bin for global access
ln -sf "$svc_script" "$WW_HOME/bin/$svc_short"

echo ">>> Service '$svc_name' created successfully."
echo ">>> You can now call '$svc_short' inside 'ww' or globally."
echo ">>> Metadata added to script header for management."

INDEX_FILE="$WW_HOME/services/index/index.json"

# Initialize JSON array if missing
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "[]" > "$INDEX_FILE"
fi

# Escape JSON special characters
escape_json() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Build new service entry as JSON object
new_entry=$(cat <<EOF
{
  "shortname": $(escape_json "$svc_short"),
  "name": $(escape_json "$svc_name"),
  "author": $(escape_json "$AUTHOR"),
  "created": "$(date '+%Y-%m-%d %H:%M:%S')",
  "version": $(escape_json "$svc_version"),
  "description": $(escape_json "$svc_desc"),
  "connections": $(escape_json "$svc_conn"),
  "script": $(escape_json "$svc_script")
}
EOF
)

# Append to JSON array
tmpfile=$(mktemp)
jq ". += [$new_entry]" "$INDEX_FILE" > "$tmpfile" && mv "$tmpfile" "$INDEX_FILE"

echo ">>> Service registry updated at $INDEX_FILE"
