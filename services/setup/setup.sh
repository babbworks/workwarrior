#!/usr/bin/env bash
set -e

WW_DIR="$HOME/ww"
BIN_PATH="$WW_DIR/bin"

echo ">>> Setting up Workwarrior at $WW_DIR"

# Ensure bin exists
mkdir -p "$BIN_PATH"

# Make sure all scripts are executable
find "$WW_DIR" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

# Add to PATH if not already there
if ! grep -q "$BIN_PATH" ~/.bashrc; then
  echo "export PATH=\"$BIN_PATH:\$PATH\"" >> ~/.bashrc
  echo ">>> Added $BIN_PATH to PATH in ~/.bashrc"
fi

echo ">>> Setup complete. Restart your shell or run:"
echo "    export PATH=\"$BIN_PATH:\$PATH\""
echo ">>> You can now run 'ww'."


#!/usr/bin/env bash
set -e

WW_DIR="$HOME/ww"
BIN_PATH="$WW_DIR/bin"

echo ">>> Setting up Workwarrior at $WW_DIR"

# Ensure bin exists
mkdir -p "$BIN_PATH"

# Make all .sh scripts executable
find "$WW_DIR/services" -type f -name "*.sh" -exec chmod +x {} \;

# Create the `ww` environment launcher
cat > "$BIN_PATH/ww" <<'EOF'
#!/usr/bin/env bash
# Workwarrior environment shell

WW_DIR="$HOME/ww/services"

echo ">>> Entering Workwarrior environment."
echo "    Type 'exit' to leave."

# Prepend service paths as commands
for s in "$WW_DIR"/*/*.sh; do
    svc=$(basename "$s" .sh)
    # Define a shell function for each service
    eval "
    $svc() {
        \"$s\" \"\$@\"
    }"
done

# Drop into subshell with Workwarrior commands active
bash --rcfile <(echo "PS1='[ww] \\u@\\h:\\w\\$ '")
EOF

chmod +x "$BIN_PATH/ww"

# Add ww to PATH if not already there
if ! grep -q "$BIN_PATH" ~/.bashrc; then
  echo "export PATH=\"$BIN_PATH:\$PATH\"" >> ~/.bashrc
  echo ">>> Added $BIN_PATH to PATH in ~/.bashrc"
fi

echo ">>> Setup complete. Restart shell or run:"
echo "    source ~/.bashrc"
echo ">>> You can now enter Workwarrior with: ww"
