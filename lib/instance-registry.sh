#!/usr/bin/env bash
# Instance registry helpers (directory-manifest based)

ww_config_home() {
  echo "${WW_CONFIG_HOME:-$HOME/.config/ww}"
}

ww_registry_dir() {
  echo "${WW_REGISTRY_DIR:-$(ww_config_home)/registry}"
}

ww_registry_init() {
  mkdir -p "$(ww_registry_dir)"
}

ww_manifest_path() {
  local iid="$1"
  echo "$(ww_registry_dir)/$iid.json"
}

ww_instance_register() {
  local iid="$1"
  local install_path="$2"
  local visibility="${3:-visible}"
  local alias_name="${4:-$iid}"
  local preset="${5:-multi}"
  local command_name="${6:-ww}"
  local backend="${7:-auto}"
  local parent_anchor="${8:-}"
  local lock_required="false"
  [[ "$preset" == "hardened" ]] && lock_required="true"

  ww_registry_init || return 1
  cat > "$(ww_manifest_path "$iid")" << JSON
{
  "id": "$iid",
  "alias": "$alias_name",
  "version": "${WW_VERSION:-1.0.0}",
  "visibility": "$visibility",
  "install_path": "$install_path",
  "preset": "$preset",
  "command_name": "$command_name",
  "security_backend": "$backend",
  "lock_required": $lock_required,
  "parent_anchor": "${parent_anchor:-null}",
  "allowed_orchestrators": [${parent_anchor:+\"$parent_anchor\"}],
  "registered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "active"
}
JSON
}

ww_instance_set_visibility() {
  local iid="$1"
  local vis="$2"
  local mf
  mf="$(ww_manifest_path "$iid")"
  [[ -f "$mf" ]] || return 1
  python3 - "$mf" "$vis" << 'PY'
import json,sys
p,v=sys.argv[1],sys.argv[2]
d=json.load(open(p))
d["visibility"]=v
json.dump(d,open(p,"w"),indent=2)
print()
PY
}

ww_instance_detach() {
  local iid="$1"
  rm -f "$(ww_manifest_path "$iid")"
}

ww_instance_list() {
  local include_hidden="${1:-0}"
  local dir
  dir="$(ww_registry_dir)"
  [[ -d "$dir" ]] || return 0
  local f
  for f in "$dir"/*.json; do
    [[ -f "$f" ]] || continue
    python3 - "$f" "$include_hidden" << 'PY'
import json,sys
d=json.load(open(sys.argv[1]))
inc=sys.argv[2]=="1"
if d.get("visibility") == "hidden" and not inc:
    sys.exit(0)
print(f"{d.get('id','')}\t{d.get('alias','')}\t{d.get('version','')}\t{d.get('visibility','visible')}\t{d.get('status','active')}")
PY
  done
}

ww_instance_where() {
  local iid="$1"
  local mf
  mf="$(ww_manifest_path "$iid")"
  [[ -f "$mf" ]] || return 1
  python3 - "$mf" << 'PY'
import json,sys
print(json.load(open(sys.argv[1])).get("install_path",""))
PY
}

ww_instance_lookup() {
  local key="$1"
  local include_hidden="${2:-0}"
  local dir
  dir="$(ww_registry_dir)"
  [[ -d "$dir" ]] || return 1
  local f
  for f in "$dir"/*.json; do
    [[ -f "$f" ]] || continue
    if python3 - "$f" "$key" "$include_hidden" << 'PY'
import json,sys
p,k,inc=sys.argv[1],sys.argv[2],sys.argv[3]=="1"
d=json.load(open(p))
if d.get("visibility") == "hidden" and not inc:
    raise SystemExit(1)
if d.get("id")==k or d.get("alias")==k:
    print(d.get("id",""))
    raise SystemExit(0)
raise SystemExit(1)
PY
    then
      return 0
    fi
  done
  return 1
}

ww_set_last_instance() {
  local iid="$1"
  local cfg_home="${WW_CONFIG_HOME:-$HOME/.config/ww}"
  mkdir -p "$cfg_home"
  printf '%s\n' "$iid" > "$cfg_home/last-instance"
}

ww_get_last_instance() {
  local f="${WW_CONFIG_HOME:-$HOME/.config/ww}/last-instance"
  [[ -f "$f" ]] || return 1
  cat "$f"
}

ww_instance_lock_required() {
  local iid="$1"
  local mf
  mf="$(ww_manifest_path "$iid")"
  [[ -f "$mf" ]] || { echo "false"; return 0; }
  python3 - "$mf" << 'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print("true" if d.get("lock_required", False) else "false")
PY
}
