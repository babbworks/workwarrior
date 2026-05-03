#!/usr/bin/env bash
# Security backend detection and unlock helpers

ww_detect_security_backend() {
  local preferred="${1:-auto}"
  case "$preferred" in
    keychain|libsecret|pass)
      echo "$preferred"; return 0 ;;
  esac

  case "$(uname -s)" in
    Darwin)
      if command -v security >/dev/null 2>&1; then echo "keychain"; return 0; fi ;;
    Linux)
      if command -v secret-tool >/dev/null 2>&1; then echo "libsecret"; return 0; fi
      if command -v pass >/dev/null 2>&1; then echo "pass"; return 0; fi
      ;;
  esac
  echo "weak"
}

ww_unlock_instance() {
  local instance_id="$1"
  local backend="$2"
  case "$backend" in
    keychain)
      security find-generic-password -a "$USER" -s "ww/${instance_id}" -w >/dev/null 2>&1
      ;;
    libsecret)
      secret-tool lookup ww instance "$instance_id" >/dev/null 2>&1
      ;;
    pass)
      pass "ww/${instance_id}" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

ww_store_instance_secret() {
  local instance_id="$1"
  local backend="$2"
  local secret="$3"
  case "$backend" in
    keychain)
      security add-generic-password -U -a "$USER" -s "ww/${instance_id}" -w "$secret" >/dev/null 2>&1
      ;;
    libsecret)
      secret-tool store --label="ww ${instance_id}" ww instance "$instance_id" >/dev/null 2>&1 <<< "$secret"
      ;;
    pass)
      printf '%s\n' "$secret" | pass insert -m -f "ww/${instance_id}" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

ww_keyctl_available() {
  [[ "$(uname -s)" == "Linux" ]] && command -v keyctl >/dev/null 2>&1
}

ww_session_token_set() {
  local instance_id="$1"
  local ttl="${2:-900}"
  if ww_keyctl_available; then
    # Persist token in user keyring with expiration to avoid repeated unlock prompts.
    keyctl padd user "ww_unlock_${instance_id}" @u >/dev/null 2>&1 <<< "1" || return 1
    keyctl timeout "$(keyctl search @u user "ww_unlock_${instance_id}" 2>/dev/null)" "$ttl" >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

ww_session_token_valid() {
  local instance_id="$1"
  if ww_keyctl_available; then
    keyctl search @u user "ww_unlock_${instance_id}" >/dev/null 2>&1
    return $?
  fi
  return 1
}

ww_session_token_clear() {
  local instance_id="$1"
  if ww_keyctl_available; then
    local kid
    kid="$(keyctl search @u user "ww_unlock_${instance_id}" 2>/dev/null || true)"
    [[ -n "$kid" ]] && keyctl revoke "$kid" >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}
