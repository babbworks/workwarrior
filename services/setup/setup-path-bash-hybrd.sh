#!/usr/bin/env bash
set -e

WW_HOME="$HOME/ww"
BIN_PATH="$WW_HOME/bin"
WW_RC="$WW_HOME/.wwrc"

echo ">>> Setting up Workwarrior in $WW_HOME"

# 1️⃣ Ensure bin and services directories exist
mkdir -p "$BIN_PATH"
mkdir -p "$WW_HOME/services"

# 2️⃣ Make all .sh scripts executable
find "$WW_HOME/services" -type f -name "*.sh" -exec chmod +x {} \;

# 3️⃣ Create ww launcher in bin/
cat > "$BIN_PATH/ww" <<'EOF'
#!/usr/bin/env bash
# Workwarrior immersive shell

WW_HOME="$HOME/ww"
WW_RC="$WW_HOME/.wwrc"

if [[ -f "$WW_RC" ]]; then
    bash --rcfile "$WW_RC" -i
else
    echo ">>> Workwarrior environment not found. Please run setup.sh again."
fi
EOF

chmod +x "$BIN_PATH/ww"

# 4️⃣ Create .wwrc if missing
if [[ ! -f "$WW_RC" ]]; then
cat > "$WW_RC" <<'EOF'
#!/usr/bin/env bash
# Workwarrior session environment

WW_HOME="$HOME/ww"

# Prepend bin to PATH (higher priority)
export PATH="$WW_HOME/bin:$PATH"

# Optional immersive PS1
PS1="[ww] \u@\h:\w$ "

# Dynamically define functions for all services
for s in "$WW_HOME"/services/*/*.sh; do
    svc=$(basename "$s" .sh)
    eval "
    $svc() {
        \"$s\" \"\$@\"
    }"
done
EOF
fi

# 5️⃣ Add to PATH and define ww function in .bashrc
BASHRC="$HOME/.bashrc"
if ! grep -q "### Workwarrior PATH ###" "$BASHRC"; then
cat >> "$BASHRC" <<'EOF'

### Workwarrior PATH ###
export WW_HOME="$HOME/ww"
export PATH="$WW_HOME/bin:$PATH"

ww() {
    echo ">>> Launching Workwarrior session..."
    bash --rcfile "$WW_HOME/.wwrc" -i
}
### End Workwarrior PATH ###
EOF
    echo ">>> Added Workwarrior PATH and ww() function to ~/.bashrc"
fi

echo ">>> Setup complete!"
echo ">>> Open a new terminal or run: source ~/.bashrc"
echo ">>> You can now run commands like 'profile', 'task', 'new', etc."
echo ">>> Or enter the immersive environment with 'ww'"
