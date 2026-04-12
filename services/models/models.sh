#!/usr/bin/env bash
# Service: models
# Category: models
# Description: Manage local and remote LLM provider/model configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

MODELS_CONFIG="${WW_BASE:-$HOME/ww}/config/models.yaml"

get_default_model() {
  awk '
    BEGIN { in_models=0 }
    /^models:[[:space:]]*$/ { in_models=1; next }
    in_models && /^[^[:space:]]/ { in_models=0 }
    in_models && /^  default:[[:space:]]*/ {
      line=$0
      sub(/^  default:[[:space:]]*/, "", line)
      gsub(/^"/, "", line)
      gsub(/"$/, "", line)
      print line
      exit
    }
  ' "$MODELS_CONFIG"
}

list_model_names() {
  awk '
    BEGIN { in_models=0 }
    /^models:[[:space:]]*$/ { in_models=1; next }
    in_models && /^[^[:space:]]/ { in_models=0 }
    in_models && /^  [A-Za-z0-9_.:-]+:[[:space:]]*$/ {
      name=$1
      sub(/:$/, "", name)
      if (name != "default") {
        print name
      }
    }
  ' "$MODELS_CONFIG"
}

list_provider_names() {
  awk '
    BEGIN { in_providers=0 }
    /^providers:[[:space:]]*$/ { in_providers=1; next }
    in_providers && /^[^[:space:]]/ { in_providers=0 }
    in_providers && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ {
      name=$1
      sub(/:$/, "", name)
      print name
    }
  ' "$MODELS_CONFIG"
}

provider_has_models() {
  local provider="$1"
  awk -v target="$provider" '
    BEGIN { in_models=0; in_block=0; count=0 }
    /^models:[[:space:]]*$/ { in_models=1; next }
    in_models && /^[^[:space:]]/ { in_models=0; in_block=0 }
    in_models && /^  [A-Za-z0-9_.:-]+:[[:space:]]*$/ {
      name=$1
      sub(/:$/, "", name)
      in_block=(name != "default")
      next
    }
    in_models && in_block && /^    provider:[[:space:]]*/ {
      p=$0
      sub(/^    provider:[[:space:]]*/, "", p)
      gsub(/^"/, "", p)
      gsub(/"$/, "", p)
      if (p == target) {
        count++
      }
      in_block=0
    }
    END {
      print count
    }
  ' "$MODELS_CONFIG"
}

provider_env_pairs() {
  awk '
    BEGIN { in_providers=0; provider="" }
    /^providers:[[:space:]]*$/ { in_providers=1; next }
    in_providers && /^[^[:space:]]/ { in_providers=0; provider="" }
    in_providers && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ {
      provider=$1
      sub(/:$/, "", provider)
      next
    }
    in_providers && /^    api_key_env:[[:space:]]*/ && provider != "" {
      env=$0
      sub(/^    api_key_env:[[:space:]]*/, "", env)
      gsub(/^"/, "", env)
      gsub(/"$/, "", env)
      if (env != "") {
        print provider ":" env
      }
    }
  ' "$MODELS_CONFIG"
}

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
  while IFS= read -r name; do
    echo "  • $name"
    any=true
  done < <(list_model_names)
  if [[ "$any" == false ]]; then
    echo "  (none)"
  fi
  echo ""
  local def
  def=$(get_default_model)
  echo "Default: ${def:-"(none)"}"
}

list_providers() {
  ensure_models_config
  echo "Providers:"
  local any=false
  while IFS= read -r name; do
    echo "  • $name"
    any=true
  done < <(list_provider_names)
  if [[ "$any" == false ]]; then
    echo "  (none)"
  fi
}

show_model() {
  local name="$1"
  validate_name "$name" || return 1
  ensure_models_config
  local in_block=0
  local found=0
  echo "Model: $name"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]{2}${name}:[[:space:]]*$ ]]; then
      in_block=1
      found=1
      continue
    fi
    if [[ $in_block -eq 1 && "$line" =~ ^[[:space:]]{2}[a-zA-Z0-9_.:-]+:[[:space:]]*$ ]]; then
      break
    fi
    if [[ $in_block -eq 1 && "$line" =~ ^[a-zA-Z0-9_.:-]+:[[:space:]]*$ ]]; then
      break
    fi
    if [[ $in_block -eq 1 ]]; then
      echo "  ${line#    }"
    fi
  done < "$MODELS_CONFIG"
  if [[ $found -eq 0 ]]; then
    log_error "Model not found: $name"
    return 1
  fi
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

remove_provider() {
  local name="$1"
  validate_name "$name" || return 1
  ensure_models_config
  if ! list_provider_names | grep -Fxq "$name"; then
    log_error "Provider not found: $name"
    return 1
  fi
  local used_count
  used_count=$(provider_has_models "$name")
  if [[ "${used_count:-0}" -gt 0 ]]; then
    log_error "Cannot remove provider '$name' while ${used_count} model(s) reference it"
    return 1
  fi
  local tmp="${MODELS_CONFIG}.tmp"
  awk -v name="$name" '
    BEGIN { in_p=0 }
    $0 ~ "^  " name ":[[:space:]]*$" { in_p=1; next }
    in_p && $0 ~ "^  [a-zA-Z0-9_.-]+:[[:space:]]*$" { in_p=0 }
    in_p && $0 ~ "^[a-zA-Z0-9_.:-]+:[[:space:]]*$" { in_p=0 }
    in_p { next }
    { print }
  ' "$MODELS_CONFIG" > "$tmp"
  mv "$tmp" "$MODELS_CONFIG"
  log_success "Removed provider: $name"
}

add_model() {
  local name="$1"
  local provider="$2"
  local model_id="$3"
  local notes="${4:-}"
  validate_name "$name" || return 1
  validate_name "$provider" || return 1
  ensure_models_config
  if list_model_names | grep -Fxq "$name"; then
    log_error "Model already exists: $name"
    return 1
  fi
  if ! list_provider_names | grep -Fxq "$provider"; then
    log_warning "Provider not found: $provider (still adding)"
  fi

  awk -v name="$name" -v provider="$provider" -v mid="$model_id" -v notes="$notes" '
    /^models:/ { print; in_m=1; next }
    in_m && /^[^ ]/ { 
      print "  " name ":";
      print "    provider: " provider;
      print "    id: " mid;
      if (notes != "") print "    notes: " notes;
      in_m=0 
    }
    { print }
    END {
      if (in_m) {
        print "  " name ":"
        print "    provider: " provider
        print "    id: " mid
        if (notes != "") print "    notes: " notes
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
  if ! list_model_names | grep -Fxq "$name"; then
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
  if ! list_model_names | grep -Fxq "$name"; then
    log_error "Model not found: $name"
    return 1
  fi
  local def
  def=$(get_default_model)
  if [[ -n "$def" && "$def" == "$name" ]]; then
    log_error "Cannot remove default model: $name"
    return 1
  fi
  local tmp="${MODELS_CONFIG}.tmp"
  awk -v name="$name" '
    BEGIN { in_m=0 }
    $0 ~ "^  " name ":[[:space:]]*$" { in_m=1; next }
    in_m && $0 ~ "^  [a-zA-Z0-9_.:-]+:[[:space:]]*$" { in_m=0 }
    in_m && $0 ~ "^[a-zA-Z0-9_.:-]+:[[:space:]]*$" { in_m=0 }
    in_m { next }
    { print }
  ' "$MODELS_CONFIG" > "$tmp"
  mv "$tmp" "$MODELS_CONFIG"
  log_success "Removed model: $name"
}

show_help() {
  cat << EOF
Models Service

Usage: ww model <action> [arguments]
Alias: ww models (bare alias defaults to list)

Actions:
  <name> <type> <base_url> [api_key_env]
                              Shortcut for add-provider (singular create form)
  list                         List models and default
  providers                    List providers
  env                          Show provider environment variables
  check                        Check if required env vars are set
  show <model>                 Show model details
  add-provider <name> <type> <base_url> [api_key_env]
  remove-provider <name>       Remove provider (must not be referenced by models)
  add-model <name> <provider> <model_id> [notes]
  set-default <name>           Set default model
  remove-model <name>          Remove model

Examples:
  ww model list
  ww model providers
  ww model env
  ww model check
  ww model openai openai https://api.openai.com/v1 OPENAI_API_KEY
  ww model add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
  ww model remove-provider openai
  ww model add-model gpt-4o-mini openai gpt-4o-mini "fast"
  ww model set-default gpt-4o-mini
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
      while IFS=: read -r provider env; do
        [[ -n "$provider" && -n "$env" ]] || continue
        echo "  $provider: $env"
      done < <(provider_env_pairs)
      ;;
    check)
      ensure_models_config
      local missing=0
      echo "Provider Environment Check:"
      while IFS=: read -r provider env; do
        [[ -n "$provider" && -n "$env" ]] || continue
        if [[ -z "${!env:-}" ]]; then
          echo "  ✗ $provider ($env not set)"
          missing=1
        else
          echo "  ✓ $provider ($env set)"
        fi
      done < <(provider_env_pairs)
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
    remove-provider)
      [[ -z "${1:-}" ]] && { log_error "Provider name required"; exit 1; }
      remove_provider "$1"
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
      # Singular create form: ww model <name> <type> <base_url> [api_key_env]
      if [[ -n "$action" && -n "${1:-}" && -n "${2:-}" ]]; then
        add_provider "$action" "$1" "$2" "${3:-}"
      else
        log_error "Unknown action: $action"
        show_help
        exit 1
      fi
      ;;
  esac
}

main "$@"
