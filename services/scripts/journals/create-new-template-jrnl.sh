#!/bin/bash

# Configuration
SCRIPTS_DIR="$HOME/docs/scripts/jrnl/prompts"
mkdir -p "$SCRIPTS_DIR"

read -p "New script filename (e.g., log-idea.sh): " filename
read -p "Journal name (e.g., wp): " journal
read -p "Entry title (e.g., Workpads @Story): " entry_title

echo "Enter field names (one per line). End input with an empty line:"
fields=()
while true; do
    read -p "> " field
    [[ -z "$field" ]] && break
    fields+=("$field")
done

# Determine full script path
script_path="$SCRIPTS_DIR/$filename"

# Start building the script content
cat > "$script_path" <<EOF
#!/bin/bash

# Prompt the user for structured input
EOF

# Write input prompts
for field in "${fields[@]}"; do
    varname=$(echo "$field" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    echo "read -p \"$field: \" $varname" >> "$script_path"
done

# Begin heredoc section to build the entry
cat >> "$script_path" <<EOF

# Build the entry using a heredoc
entry=\$(cat <<ENTRY
\$(date +"%Y-%m-%d %I:%M %p") $entry_title
EOF

# Add field lines to the entry
for field in "${fields[@]}"; do
    varname=$(echo "$field" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    echo "$field: \$$varname" >> "$script_path"
done

# Close the heredoc and finalize logic
cat >> "$script_path" <<EOF
ENTRY
)

# Optional: Show the entry before saving
echo
echo "Entry preview:"
echo "\$entry"

read -p "Submit? [y/N] " confirm

if [[ "\$confirm" =~ ^[Yy]$ ]]; then
    echo "\$entry" | jrnl "$journal"
    echo "✅ Entry saved."
else
    echo "❌ Entry canceled."
fi
EOF

# Make the new script executable
chmod +x "$script_path"
echo "✅ Script created at: $script_path"

# Add alias for convenience
alias_base=$(basename "$filename" .sh | tr '_' '-' | tr '[:upper:]' '[:lower:]')
alias_name="$alias_base"
alias_command="alias $alias_name=\"$script_path\""

# Determine shell config file
SHELL_RC="$HOME/.bashrc"
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
fi

# Add alias to shell config if not already present
if ! grep -Fxq "$alias_command" "$SHELL_RC"; then
    echo "$alias_command" >> "$SHELL_RC"
    echo "✅ Alias added to $SHELL_RC: $alias_name"
    echo "⏳ Run 'source $SHELL_RC' or restart your terminal to activate."
else
    echo "ℹ️ Alias already exists in $SHELL_RC: $alias_name"
fi

