#!/usr/bin/env bash
# Service: ctrl
# Category: ctrl
# Description: Manage AI and command-line control settings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

AI_CONFIG="${WW_BASE:-$HOME/ww}/config/ai.yaml"
CTRL_CONFIG="${WW_BASE:-$HOME/ww}/config/ctrl.yaml"
MODELS_CONFIG="${WW_BASE:-$HOME/ww}/config/models.yaml"

ensure_ai_config() {
  if [[ -f "$AI_CONFIG" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$AI_CONFIG")"
  cat > "$AI_CONFIG" << 'EOF'
mode: local-only
access_points:
  cmd_ai: true
  sword_ai: false
  questions_ai: false
  saves_ai: false
preferred_provider: ollama
EOF
}

ensure_ctrl_config() {
  if [[ -f "$CTRL_CONFIG" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$CTRL_CONFIG")"
  cat > "$CTRL_CONFIG" << 'EOF'
command_line:
  show_ww: true
  show_ai: true
ui:
  show_active_model: true
EOF
}

read_ai_mode() {
  awk '/^mode:[[:space:]]*/ { print $2; exit }' "$AI_CONFIG"
}

read_ai_cmd_enabled() {
  awk '
    BEGIN { in_ap=0 }
    /^access_points:[[:space:]]*$/ { in_ap=1; next }
    in_ap && /^[^[:space:]]/ { in_ap=0 }
    in_ap && /^  cmd_ai:[[:space:]]*/ { print $2; exit }
  ' "$AI_CONFIG"
}

read_preferred_provider() {
  awk '/^preferred_provider:[[:space:]]*/ { print $2; exit }' "$AI_CONFIG"
}

read_default_model() {
  awk '
    BEGIN { in_m=0 }
    /^models:[[:space:]]*$/ { in_m=1; next }
    in_m && /^[^[:space:]]/ { in_m=0 }
    in_m && /^  default:[[:space:]]*/ {
      v=$0
      sub(/^  default:[[:space:]]*/, "", v)
      gsub(/^"/, "", v)
      gsub(/"$/, "", v)
      print v
      exit
    }
  ' "$MODELS_CONFIG" 2>/dev/null || true
}

read_default_model_provider() {
  local model="${1:-}"
  [[ -n "$model" ]] || return 0
  awk -v model="$model" '
    BEGIN { in_m=0; in_block=0 }
    /^models:[[:space:]]*$/ { in_m=1; next }
    in_m && /^[^[:space:]]/ { in_m=0; in_block=0 }
    in_m && $0 ~ "^  " model ":[[:space:]]*$" { in_block=1; next }
    in_block && /^  [A-Za-z0-9_.:-]+:[[:space:]]*$/ { in_block=0 }
    in_block && /^    provider:[[:space:]]*/ {
      v=$0
      sub(/^    provider:[[:space:]]*/, "", v)
      gsub(/^"/, "", v)
      gsub(/"$/, "", v)
      print v
      exit
    }
  ' "$MODELS_CONFIG" 2>/dev/null || true
}

read_ctrl_bool() {
  local section="$1"
  local key="$2"
  awk -v section="$section" -v key="$key" '
    $0 ~ "^" section ":[[:space:]]*$" { in_s=1; next }
    in_s && /^[^[:space:]]/ { in_s=0 }
    in_s && $0 ~ "^  " key ":[[:space:]]*" {
      print $2
      exit
    }
  ' "$CTRL_CONFIG"
}

set_ai_mode() {
  local mode="$1"
  case "$mode" in
    off|local-only|local+remote) ;;
    *) log_error "Invalid AI mode: $mode"; return 1 ;;
  esac
  sed -i.bak "s/^mode:.*/mode: ${mode}/" "$AI_CONFIG" && rm -f "$AI_CONFIG.bak"
  log_success "AI mode set to: $mode"
}

set_ai_cmd() {
  local val="$1"
  local bool
  case "$val" in
    on|true|1) bool="true" ;;
    off|false|0) bool="false" ;;
    *) log_error "Value must be on/off"; return 1 ;;
  esac
  awk -v bool="$bool" '
    BEGIN { in_ap=0; done=0 }
    /^access_points:[[:space:]]*$/ { print; in_ap=1; next }
    in_ap && /^  cmd_ai:[[:space:]]*/ { print "  cmd_ai: " bool; done=1; next }
    in_ap && /^[^[:space:]]/ && done==0 { print "  cmd_ai: " bool; in_ap=0 }
    { print }
    END {
      if (in_ap && done==0) print "  cmd_ai: " bool
    }
  ' "$AI_CONFIG" > "${AI_CONFIG}.tmp"
  mv "${AI_CONFIG}.tmp" "$AI_CONFIG"
  log_success "CTRL cmd_ai set to: $bool"
}

set_ctrl_bool() {
  local section="$1"
  local key="$2"
  local val="$3"
  local bool
  case "$val" in
    on|true|1) bool="true" ;;
    off|false|0) bool="false" ;;
    *) log_error "Value must be on/off"; return 1 ;;
  esac
  awk -v section="$section" -v key="$key" -v bool="$bool" '
    BEGIN { in_s=0; section_seen=0; key_set=0 }
    $0 ~ "^" section ":[[:space:]]*$" { print; in_s=1; section_seen=1; next }
    in_s && /^[^[:space:]]/ {
      if (key_set==0) print "  " key ": " bool
      in_s=0
    }
    in_s && $0 ~ "^  " key ":[[:space:]]*" {
      print "  " key ": " bool
      key_set=1
      next
    }
    { print }
    END {
      if (section_seen==0) {
        print section ":"
        print "  " key ": " bool
      } else if (in_s && key_set==0) {
        print "  " key ": " bool
      }
    }
  ' "$CTRL_CONFIG" > "${CTRL_CONFIG}.tmp"
  mv "${CTRL_CONFIG}.tmp" "$CTRL_CONFIG"
  log_success "${section}.${key} set to: $bool"
}

_probe_ollama() {
  # Quick probe of ollama — 1 second timeout
  local url="http://localhost:11434/api/tags"
  if command -v curl &>/dev/null; then
    local response
    response=$(curl -s --max-time 1 "$url" 2>/dev/null) || {
      log_warning "ollama not reachable at localhost:11434"
      echo "  Start with: ollama serve"
      echo "  Install: brew install ollama"
      return 1
    }
    local model_count
    model_count=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null || echo "0")
    if [[ "$model_count" -gt 0 ]]; then
      local models
      models=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(', '.join(m['name'] for m in d.get('models',[])))" 2>/dev/null)
      log_success "ollama running · $model_count model(s): $models"
      export WW_OLLAMA_AVAILABLE=1
      return 0
    else
      log_warning "ollama running but no models installed"
      echo "  Pull a model: ollama pull llama3.2"
      return 1
    fi
  else
    log_warning "curl not available — cannot probe ollama"
    return 1
  fi
}

_show_ai_status() {
  ensure_ai_config
  local mode cmd_ai preferred
  mode="$(read_ai_mode)"
  cmd_ai="$(read_ai_cmd_enabled)"
  preferred="$(read_preferred_provider)"

  echo "AI Status"
  echo "========="
  echo "  mode: $mode"
  echo "  cmd_ai: $cmd_ai"
  echo "  preferred: $preferred"
  echo ""

  # Check per-profile override
  if [[ -n "${WORKWARRIOR_BASE:-}" && -f "$WORKWARRIOR_BASE/ai.yaml" ]]; then
    local profile_mode
    profile_mode=$(awk '/^mode:/ { print $2; exit }' "$WORKWARRIOR_BASE/ai.yaml")
    echo "  profile override: $profile_mode (from $WORKWARRIOR_BASE/ai.yaml)"
  else
    echo "  profile override: none (using global)"
  fi
  echo ""

  # Probe ollama
  echo "Ollama:"
  _probe_ollama || true
}

show_status() {
  ensure_ai_config
  ensure_ctrl_config
  local mode cmd_ai preferred default_model default_provider show_ww show_ai show_active
  mode="$(read_ai_mode)"
  cmd_ai="$(read_ai_cmd_enabled)"
  preferred="$(read_preferred_provider)"
  default_model="$(read_default_model)"
  default_provider="$(read_default_model_provider "$default_model")"
  show_ww="$(read_ctrl_bool command_line show_ww)"
  show_ai="$(read_ctrl_bool command_line show_ai)"
  show_active="$(read_ctrl_bool ui show_active_model)"

  if [[ "${WW_OUTPUT_MODE:-human}" == "json" ]]; then
    cat <<EOF
{"ai":{"mode":"${mode}","cmd_ai":${cmd_ai:-false},"preferred_provider":"${preferred}","default_model":"${default_model}","default_provider":"${default_provider}"},"command_line":{"show_ww":${show_ww:-true},"show_ai":${show_ai:-true}},"ui":{"show_active_model":${show_active:-true}}}
EOF
    return 0
  fi

  echo "CTRL Settings"
  echo ""
  echo "AI:"
  echo "  mode: ${mode}"
  echo "  cmd_ai: ${cmd_ai}"
  echo "  preferred_provider: ${preferred}"
  echo "  default_model: ${default_model:-"(none)"}"
  echo "  default_provider: ${default_provider:-"(none)"}"
  echo ""
  echo "Command line:"
  echo "  show_ww: ${show_ww}"
  echo "  show_ai: ${show_ai}"
  echo ""
  echo "UI:"
  echo "  show_active_model: ${show_active}"
}

show_help() {
  cat << 'EOF'
CTRL Service

Usage: ww ctrl <action> [arguments]

Actions:
  status                          Show current CTRL settings
  ai-mode <off|local-only|local+remote>
                                  Set AI mode
  ai-cmd <on|off>                 Enable or disable CMD AI access point
  ai-on                           Enable AI (local-only) + check ollama
  ai-off                          Disable all AI
  ai-status                       Show AI status + ollama probe + profile override
  prompt-ww <on|off>              Show or hide `ww` command-line indicator
  prompt-ai <on|off>              Show or hide `(AI)` indicator when AI is active
  ui-model-indicator <on|off>     Show/hide active model indicator in browser UI
  help                            Show this help

Examples:
  ww ctrl status
  ww ctrl ai-mode local-only
  ww ctrl ai-cmd on
  ww ctrl prompt-ww on
  ww ctrl prompt-ai on
  ww ctrl ui-model-indicator on
EOF
}

main() {
  ensure_ai_config
  ensure_ctrl_config

  local action="${1:-status}"
  shift 2>/dev/null || true

  case "$action" in
    status|list)
      show_status
      ;;
    ai-mode)
      [[ -n "${1:-}" ]] || { log_error "Usage: ww ctrl ai-mode <off|local-only|local+remote>"; exit 1; }
      set_ai_mode "$1"
      ;;
    ai-cmd)
      [[ -n "${1:-}" ]] || { log_error "Usage: ww ctrl ai-cmd <on|off>"; exit 1; }
      set_ai_cmd "$1"
      ;;
    ai-on)
      # Convenience: enable AI with local-only mode, check ollama
      set_ai_mode "local-only"
      set_ai_cmd "on"
      _probe_ollama
      ;;
    ai-off)
      # Convenience: disable all AI
      set_ai_mode "off"
      set_ai_cmd "off"
      log_success "AI disabled"
      ;;
    ai-status)
      _show_ai_status
      ;;
    prompt-ww)
      [[ -n "${1:-}" ]] || { log_error "Usage: ww ctrl prompt-ww <on|off>"; exit 1; }
      set_ctrl_bool "command_line" "show_ww" "$1"
      ;;
    prompt-ai)
      [[ -n "${1:-}" ]] || { log_error "Usage: ww ctrl prompt-ai <on|off>"; exit 1; }
      set_ctrl_bool "command_line" "show_ai" "$1"
      ;;
    ui-model-indicator)
      [[ -n "${1:-}" ]] || { log_error "Usage: ww ctrl ui-model-indicator <on|off>"; exit 1; }
      set_ctrl_bool "ui" "show_active_model" "$1"
      ;;
    help|-h|--help)
      show_help
      ;;
    *)
      log_error "Unknown ctrl action: $action"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
