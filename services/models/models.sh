#!/usr/bin/env bash
# Service: models
# Category: models
# Description: Manage local and remote LLM provider/model configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

MODELS_CONFIG="${WW_BASE:-$HOME/ww}/config/models.yaml"

ensure_models_config() {
  local cfg="$MODELS_CONFIG"
  if [[ ! -f "$cfg" ]]; then
    mkdir -p "$(dirname "$cfg")"
    cat > "$cfg" << 'EOF'
models:
  default: ""
providers:
  openai:
    type: openai
    base_url: https://api.openai.com/v1
    api_key_env: OPENAI_API_KEY
  ollama:
    type: ollama
    base_url: http://localhost:11434
    api_key_env: ""
EOF
  fi
}

validate_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    log_error "Name cannot be empty"
    return 1
  fi
  if [[ ! "$name" =~ ^[a-zA-Z0-9_.:-]+$ ]]; then
    log_error "Name must contain only letters, numbers, dash, underscore, dot, or colon"
    return 1
  fi
  return 0
}

list_models() {
  ensure_models_config
  echo "Models:"
  local any=false
  while IFS= read -r line; do
    echo "  • ${line#    }"
    any=true
  done < <(grep "^    " "$MODELS_CONFIG" | awk -F: '{print $1}' | grep -v "^$")
  if [[ "$any" == false ]]; then
    echo "  (none)"
  fi
  echo ""
  local def
  def=$(grep "^  default:" "$MODELS_CONFIG" | awk -F": " '{print $2}')
  echo "Default: ${def:-"(none)"}"
}

list_providers() {
  ensure_models_config
  echo "Providers:"
  local any=false
  while IFS= read -r line; do
    echo "  • ${line#  }"
    any=true
  done < <(grep "^  [a-zA-Z0-9_.-]\+:" "$MODELS_CONFIG" | sed 's/:.*//' | grep -v "^models$" | grep -v "^providers$")
  if [[ "$any" == false ]]; then
    echo "  (none)"
  fi
}

show_model() {
  local name="$1"
  validate_name "$name" || return 1
  ensure_models_config
  local in_block=0
  echo "Model: $name"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]{4}${name}:[[:space:]]*$ ]]; then
      in_block=1
      continue
    fi
    if [[ $in_block -eq 1 && "$line" =~ ^[[:space:]]{4}[a-zA-Z0-9_.:-]+:[[:space:]]*$ ]]; then
      break
    fi
    if [[ $in_block -eq 1 ]]; then
      echo "  ${line#      }"
    fi
  done < "$MODELS_CONFIG"
}

add_provider() {
  local name="$1"
  local type="$2"
  local base_url="$3"
  local api_key_env="${4:-}"
  validate_name "$name" || return 1
  ensure_models_config
  if grep -q "^  ${name}:" "$MODELS_CONFIG"; then
    log_error "Provider already exists: $name"
    return 1
  fi
  awk -v name="$name" -v type="$type" -v base="$base_url" -v env="$api_key_env" '
    /^providers:/ { print; in_p=1; next }
    in_p && /^[^ ]/ { 
      print "  " name ":"; 
      print "    type: " type; 
      print "    base_url: " base; 
      print "    api_key_env: " env; 
      in_p=0 
    }
    { print }
    END {
      if (in_p) {
        print "  " name ":"
        print "    type: " type
        print "    base_url: " base
        print "    api_key_env: " env
      }
    }
  ' "$MODELS_CONFIG" > "$MODELS_CONFIG.tmp"
  mv "$MODELS_CONFIG.tmp" "$MODELS_CONFIG"
  log_success "Added provider: $name"
}

add_model() {
  local name="$1"
  local provider="$2"
  local model_id="$3"
  local notes="${4:-}"
  validate_name "$name" || return 1
  validate_name "$provider" || return 1
  ensure_models_config
  if grep -q "^    ${name}:" "$MODELS_CONFIG"; then
    log_error "Model already exists: $name"
    return 1
  fi
  if ! grep -q "^  ${provider}:" "$MODELS_CONFIG"; then
    log_warning "Provider not found: $provider (still adding)"
  fi

  awk -v name="$name" -v provider="$provider" -v mid="$model_id" -v notes="$notes" '
    /^models:/ { print; in_m=1; next }
    in_m && /^[^ ]/ { 
      print "    " name ":"; 
      print "      provider: " provider; 
      print "      id: " mid; 
      if (notes != "") print "      notes: " notes;
      in_m=0 
    }
    { print }
    END {
      if (in_m) {
        print "    " name ":"
        print "      provider: " provider
        print "      id: " mid
        if (notes != "") print "      notes: " notes
      }
    }
  ' "$MODELS_CONFIG" > "$MODELS_CONFIG.tmp"
  mv "$MODELS_CONFIG.tmp" "$MODELS_CONFIG"
  log_success "Added model: $name"
}

set_default() {
  local name="$1"
  validate_name "$name" || return 1
  ensure_models_config
  if ! grep -q "^    ${name}:" "$MODELS_CONFIG"; then
    log_error "Model not found: $name"
    return 1
  fi
  sed -i.bak "s|^  default:.*|  default: ${name}|" "$MODELS_CONFIG" && rm -f "$MODELS_CONFIG.bak"
  log_success "Default model set to: $name"
}

remove_model() {
  local name="$1"
  validate_name "$name" || return 1
  ensure_models_config
  local tmp="${MODELS_CONFIG}.tmp"
  awk -v name="$name" '
    BEGIN { in_m=0 }
    $0 ~ "^    " name ":[[:space:]]*$" { in_m=1; next }
    in_m && $0 ~ "^    [a-zA-Z0-9_.:-]+:[[:space:]]*$" { in_m=0 }
    in_m { next }
    { print }
  ' "$MODELS_CONFIG" > "$tmp"
  mv "$tmp" "$MODELS_CONFIG"
  log_success "Removed model: $name"
}

show_help() {
  cat << EOF
Models Service

Usage: ww models <action> [arguments]

Actions:
  list                         List models and default
  providers                    List providers
  env                          Show provider environment variables
  check                        Check if required env vars are set
  show <model>                 Show model details
  add-provider <name> <type> <base_url> [api_key_env]
  add-model <name> <provider> <model_id> [notes]
  set-default <name>           Set default model
  remove-model <name>          Remove model

Examples:
  ww models list
  ww models providers
  ww models env
  ww models check
  ww models add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
  ww models add-model gpt-4o-mini openai gpt-4o-mini "fast"
  ww models set-default gpt-4o-mini
EOF
}

main() {
  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    list|"")
      list_models
      ;;
    providers)
      list_providers
      ;;
    env)
      ensure_models_config
      echo "Provider Environment Variables:"
      awk '
        /^  [a-zA-Z0-9_.-]+:/ { provider=$1; sub(":", "", provider) }
        /^    api_key_env:/ {
          env=$2;
          if (env != "\"\"" && env != "''" && env != "") {
            print "  " provider ": " env
          }
        }
      ' "$MODELS_CONFIG"
      ;;
    check)
      ensure_models_config
      local missing=0
      echo "Provider Environment Check:"
      while IFS=: read -r provider env; do
        if [[ -z "${!env:-}" ]]; then
          echo "  ✗ $provider ($env not set)"
          missing=1
        else
          echo "  ✓ $provider ($env set)"
        fi
      done < <(awk '
        /^  [a-zA-Z0-9_.-]+:/ { provider=$1; sub(":", "", provider) }
        /^    api_key_env:/ {
          env=$2;
          if (env != "\"\"" && env != "''" && env != "") {
            print provider ":" env
          }
        }
      ' "$MODELS_CONFIG")
      if [[ $missing -eq 1 ]]; then
        return 1
      fi
      ;;
    show)
      [[ -z "${1:-}" ]] && { log_error "Model name required"; exit 1; }
      show_model "$1"
      ;;
    add-provider)
      [[ -z "${3:-}" ]] && { log_error "Name, type, and base_url required"; exit 1; }
      add_provider "$1" "$2" "$3" "${4:-}"
      ;;
    add-model)
      [[ -z "${3:-}" ]] && { log_error "Name, provider, and model_id required"; exit 1; }
      add_model "$1" "$2" "$3" "${4:-}"
      ;;
    set-default)
      [[ -z "${1:-}" ]] && { log_error "Model name required"; exit 1; }
      set_default "$1"
      ;;
    remove-model)
      [[ -z "${1:-}" ]] && { log_error "Model name required"; exit 1; }
      remove_model "$1"
      ;;
    help|-h|--help)
      show_help
      ;;
    *)
      log_error "Unknown action: $action"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
