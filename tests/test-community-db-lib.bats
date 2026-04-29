#!/usr/bin/env bats
# tests/test-community-db-lib.bats — TASK-COMM-001
# Tests for lib/community-db.sh shared helper functions.
# Requires: python3, bats, no network

LIB_SH="${BATS_TEST_DIRNAME}/../lib/community-db.sh"
STORE_PY="${BATS_TEST_DIRNAME}/../services/community/community_store.py"

setup() {
  export WW_BASE="${BATS_TEST_TMPDIR}/ww-lib-$$"
  export WARRIOR_PROFILE="testprofile"
  mkdir -p "$WW_BASE"
  # shellcheck source=../lib/community-db.sh
  source "$LIB_SH"
}

teardown() {
  rm -rf "$WW_BASE"
}

# ── community_list ────────────────────────────────────────────────────────────

@test "lib: community_list returns ok with empty list" {
  run community_list
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert d['communities']==[]"
}

@test "lib: community_list fails without WW_BASE" {
  local saved="$WW_BASE"
  unset WW_BASE
  run community_list
  [ "$status" -ne 0 ]
  export WW_BASE="$saved"
}

# ── community_create ──────────────────────────────────────────────────────────

@test "lib: community_create succeeds" {
  run community_create alpha
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_create duplicate returns error" {
  community_create alpha >/dev/null
  run community_create alpha
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

@test "lib: community_create without name returns error" {
  run community_create
  [ "$status" -ne 0 ]
}

@test "lib: community_list shows created community" {
  community_create beta >/dev/null
  run community_list
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); names=[c['name'] for c in d['communities']]; assert 'beta' in names"
}

# ── community_show ────────────────────────────────────────────────────────────

@test "lib: community_show returns entries" {
  community_create alpha >/dev/null
  run community_show alpha
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert 'entries' in d"
}

@test "lib: community_show unknown community fails" {
  run community_show nosuchcomm
  [ "$status" -ne 0 ]
}

# ── community_exists ──────────────────────────────────────────────────────────

@test "lib: community_exists returns 0 for existing community" {
  community_create mycomm >/dev/null
  run community_exists mycomm
  [ "$status" -eq 0 ]
}

@test "lib: community_exists returns 1 for missing community" {
  run community_exists doesnotexist
  [ "$status" -ne 0 ]
}

# ── community_add_comment ─────────────────────────────────────────────────────

@test "lib: community_add_comment inserts comment" {
  community_create alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"task for comment test","status":"pending"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.cmt-001 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run community_add_comment "$eid" "test comment body"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert d['comment_id']>0"
}

@test "lib: community_add_comment on missing entry fails" {
  run community_add_comment 99999 "orphan comment"
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

@test "lib: community_add_comment requires both args" {
  run community_add_comment 1
  [ "$status" -ne 0 ]
}

# ── community_remove_entry ────────────────────────────────────────────────────

@test "lib: community_remove_entry removes entry" {
  community_create alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"removable"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.rm-001 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run community_remove_entry alpha "$eid"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_remove_entry wrong community fails" {
  community_create alpha >/dev/null
  community_create beta >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"task"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.rm-002 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run community_remove_entry beta "$eid"
  [ "$status" -ne 0 ]
}

# ── community_entry_meta ──────────────────────────────────────────────────────

@test "lib: community_entry_meta returns source_ref" {
  community_create alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"meta task","uuid":"abc-meta-uuid"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.meta-001 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run community_entry_meta "$eid"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'source_ref' in d"
}

@test "lib: community_entry_meta on missing entry fails" {
  run community_entry_meta 99999
  [ "$status" -ne 0 ]
}

# ── community_add_journal ─────────────────────────────────────────────────────

@test "lib: community_add_journal adds journal entry" {
  community_create alpha >/dev/null
  tmp_jf="$(mktemp /tmp/tmp.XXXXXX.txt)"
  printf '[2026-04-23 10:00] Test journal entry for community\n' > "$tmp_jf"
  export JOURNAL_FILE="$tmp_jf"
  run community_add_journal alpha 2026-04-23_10-00
  rm -f "$tmp_jf"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_add_journal with invalid slug fails" {
  community_create alpha >/dev/null
  tmp_jf="$(mktemp /tmp/tmp.XXXXXX.txt)"
  export JOURNAL_FILE="$tmp_jf"
  run community_add_journal alpha "not-a-valid-slug"
  rm -f "$tmp_jf"
  [ "$status" -ne 0 ]
}

@test "lib: community_add_journal with missing journal file fails" {
  community_create alpha >/dev/null
  unset JOURNAL_FILE
  run community_add_journal alpha 2026-04-23_10-00
  [ "$status" -ne 0 ]
}

@test "lib: community_add_journal without WARRIOR_PROFILE fails" {
  community_create alpha >/dev/null
  tmp_jf="$(mktemp /tmp/tmp.XXXXXX.txt)"
  printf '[2026-04-23 11:00] entry\n' > "$tmp_jf"
  local saved="$WARRIOR_PROFILE"
  unset WARRIOR_PROFILE
  export JOURNAL_FILE="$tmp_jf"
  run community_add_journal alpha 2026-04-23_11-00
  rm -f "$tmp_jf"
  [ "$status" -ne 0 ]
  export WARRIOR_PROFILE="$saved"
}

# ── store: new CLI commands ───────────────────────────────────────────────────

@test "store: add-comment via CLI" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"cli comment test"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.cli-cmt "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run python3 "$STORE_PY" add-comment "$WW_BASE" "$eid" "cli comment text"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert d['comment_id']>0"
}

@test "store: entry-meta via CLI" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"meta test","status":"pending"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.meta-cli "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run python3 "$STORE_PY" entry-meta "$WW_BASE" "$eid"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'); assert 'source_ref' in d"
}

@test "store: entry-meta on missing entry fails" {
  run python3 "$STORE_PY" entry-meta "$WW_BASE" 99999
  [ "$status" -ne 0 ]
}

# ── store: archive / unarchive ────────────────────────────────────────────────

@test "store: archive hides community from list" {
  python3 "$STORE_PY" create "$WW_BASE" archtest >/dev/null
  python3 "$STORE_PY" archive "$WW_BASE" archtest >/dev/null
  run python3 "$STORE_PY" list "$WW_BASE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); names=[c['name'] for c in d['communities']]; assert 'archtest' not in names"
}

@test "store: archive --all shows archived communities" {
  python3 "$STORE_PY" create "$WW_BASE" archtest2 >/dev/null
  python3 "$STORE_PY" archive "$WW_BASE" archtest2 >/dev/null
  run python3 "$STORE_PY" list "$WW_BASE" --all
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); names=[c['name'] for c in d['communities']]; assert 'archtest2' in names"
}

@test "store: unarchive restores community" {
  python3 "$STORE_PY" create "$WW_BASE" unarchtest >/dev/null
  python3 "$STORE_PY" archive "$WW_BASE" unarchtest >/dev/null
  python3 "$STORE_PY" unarchive "$WW_BASE" unarchtest >/dev/null
  run python3 "$STORE_PY" list "$WW_BASE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); names=[c['name'] for c in d['communities']]; assert 'unarchtest' in names"
}

@test "store: archive missing community fails" {
  run python3 "$STORE_PY" archive "$WW_BASE" nosuchcomm
  [ "$status" -ne 0 ]
}

# ── store: describe ───────────────────────────────────────────────────────────

@test "store: describe sets community description" {
  python3 "$STORE_PY" create "$WW_BASE" desccomm >/dev/null
  run python3 "$STORE_PY" describe "$WW_BASE" desccomm "a test description"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert 'description' in d"
}

@test "store: list includes description in output" {
  python3 "$STORE_PY" create "$WW_BASE" withDesc >/dev/null
  python3 "$STORE_PY" describe "$WW_BASE" withDesc "sprint items" >/dev/null
  run python3 "$STORE_PY" list "$WW_BASE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
c = next(x for x in d['communities'] if x['name']=='withDesc')
assert c['description'] == 'sprint items'
"
}

# ── store: rename ─────────────────────────────────────────────────────────────

@test "store: rename changes community name" {
  python3 "$STORE_PY" create "$WW_BASE" oldname >/dev/null
  run python3 "$STORE_PY" rename "$WW_BASE" oldname newname
  [ "$status" -eq 0 ]
  run python3 "$STORE_PY" list "$WW_BASE"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); names=[c['name'] for c in d['communities']]; assert 'newname' in names; assert 'oldname' not in names"
}

@test "store: rename to existing name fails" {
  python3 "$STORE_PY" create "$WW_BASE" rn1 >/dev/null
  python3 "$STORE_PY" create "$WW_BASE" rn2 >/dev/null
  run python3 "$STORE_PY" rename "$WW_BASE" rn1 rn2
  [ "$status" -ne 0 ]
}

@test "store: rename missing community fails" {
  run python3 "$STORE_PY" rename "$WW_BASE" nosuch newname2
  [ "$status" -ne 0 ]
}

# ── store: modify-entry ───────────────────────────────────────────────────────

_add_test_entry() {
  local comm="$1" ref="$2"
  local tmp; tmp="$(mktemp)"
  echo '{"description":"test"}' > "$tmp"
  local out; out="$(python3 "$STORE_PY" add-entry "$WW_BASE" "$comm" "$ref" "$tmp")"
  rm -f "$tmp"
  echo "$out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])"
}

@test "store: modify-entry sets community_tags" {
  python3 "$STORE_PY" create "$WW_BASE" modcomm >/dev/null
  eid="$(_add_test_entry modcomm testprofile.task.mod-001)"
  run python3 "$STORE_PY" modify-entry "$WW_BASE" "$eid" --tags "sprint,review"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "store: modify-entry sets is_community_derivative" {
  python3 "$STORE_PY" create "$WW_BASE" modcomm2 >/dev/null
  eid="$(_add_test_entry modcomm2 testprofile.task.mod-002)"
  run python3 "$STORE_PY" modify-entry "$WW_BASE" "$eid" --derivative 1
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "store: modify-entry on missing entry fails" {
  run python3 "$STORE_PY" modify-entry "$WW_BASE" 99999 --tags "x"
  [ "$status" -ne 0 ]
}

# ── store: move-entry ─────────────────────────────────────────────────────────

@test "store: move-entry changes community" {
  python3 "$STORE_PY" create "$WW_BASE" src-comm >/dev/null
  python3 "$STORE_PY" create "$WW_BASE" dst-comm >/dev/null
  eid="$(_add_test_entry src-comm testprofile.task.mv-001)"
  run python3 "$STORE_PY" move-entry "$WW_BASE" "$eid" src-comm dst-comm
  [ "$status" -eq 0 ]
  # verify it appears in dst, not src
  dst_out="$(python3 "$STORE_PY" show "$WW_BASE" dst-comm)"
  echo "$dst_out" | python3 -c "import json,sys; d=json.load(sys.stdin); ids=[e['id'] for e in d['entries']]; assert int(sys.argv[1]) in ids" "$eid"
}

@test "store: move-entry wrong source community fails" {
  python3 "$STORE_PY" create "$WW_BASE" mvf-src >/dev/null
  python3 "$STORE_PY" create "$WW_BASE" mvf-dst >/dev/null
  python3 "$STORE_PY" create "$WW_BASE" mvf-other >/dev/null
  eid="$(_add_test_entry mvf-src testprofile.task.mv-002)"
  run python3 "$STORE_PY" move-entry "$WW_BASE" "$eid" mvf-other mvf-dst
  [ "$status" -ne 0 ]
}

# ── store: recent ─────────────────────────────────────────────────────────────

@test "store: recent returns entries across communities" {
  python3 "$STORE_PY" create "$WW_BASE" rec-a >/dev/null
  python3 "$STORE_PY" create "$WW_BASE" rec-b >/dev/null
  _add_test_entry rec-a testprofile.task.rec-001 >/dev/null
  _add_test_entry rec-b testprofile.task.rec-002 >/dev/null
  run python3 "$STORE_PY" recent "$WW_BASE" 10
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert len(d['entries']) >= 2"
}

@test "store: recent excludes archived community entries" {
  python3 "$STORE_PY" create "$WW_BASE" rec-arch >/dev/null
  _add_test_entry rec-arch testprofile.task.rec-003 >/dev/null
  python3 "$STORE_PY" archive "$WW_BASE" rec-arch >/dev/null
  run python3 "$STORE_PY" recent "$WW_BASE" 100
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
comms=[e['community_name'] for e in d['entries']]
assert 'rec-arch' not in comms, 'archived community appeared in recent'
"
}

# ── store: refresh-entry ──────────────────────────────────────────────────────

@test "store: refresh-entry updates captured_state" {
  python3 "$STORE_PY" create "$WW_BASE" rfcomm >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"original","status":"pending"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" rfcomm testprofile.task.rf-001 "$tmp")"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  echo '{"description":"updated","status":"completed"}' > "$tmp"
  run python3 "$STORE_PY" refresh-entry "$WW_BASE" rfcomm "$eid" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "store: refresh-entry wrong community fails" {
  python3 "$STORE_PY" create "$WW_BASE" rfc-a >/dev/null
  python3 "$STORE_PY" create "$WW_BASE" rfc-b >/dev/null
  eid="$(_add_test_entry rfc-a testprofile.task.rf-002)"
  tmp="$(mktemp)"
  echo '{"description":"x"}' > "$tmp"
  run python3 "$STORE_PY" refresh-entry "$WW_BASE" rfc-b "$eid" "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
}

# ── store: mark-copied ────────────────────────────────────────────────────────

@test "store: mark-copied flags comment as copied" {
  python3 "$STORE_PY" create "$WW_BASE" cpcomm >/dev/null
  eid="$(_add_test_entry cpcomm testprofile.task.cp-001)"
  cmt_out="$(python3 "$STORE_PY" add-comment "$WW_BASE" "$eid" "copy-back test")"
  cid="$(echo "$cmt_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['comment_id'])")"
  run python3 "$STORE_PY" mark-copied "$WW_BASE" "$cid"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "store: mark-copied on missing comment fails" {
  run python3 "$STORE_PY" mark-copied "$WW_BASE" 99999
  [ "$status" -ne 0 ]
}

# ── lib: new functions ────────────────────────────────────────────────────────

@test "lib: community_archive hides from list" {
  community_create libarch >/dev/null
  community_archive libarch >/dev/null
  run community_list
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'libarch' not in [c['name'] for c in d['communities']]"
}

@test "lib: community_unarchive restores" {
  community_create libunarch >/dev/null
  community_archive libunarch >/dev/null
  community_unarchive libunarch >/dev/null
  run community_list
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'libunarch' in [c['name'] for c in d['communities']]"
}

@test "lib: community_describe sets description" {
  community_create libdesc >/dev/null
  run community_describe libdesc "test description text"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_rename renames" {
  community_create libol >/dev/null
  run community_rename libol libnew
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_recent returns results" {
  community_create recentlib >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"recent test"}' > "$tmp"
  python3 "$STORE_PY" add-entry "$WW_BASE" recentlib testprofile.task.rl-001 "$tmp" >/dev/null
  rm -f "$tmp"
  run community_recent 5
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert len(d['entries']) >= 1"
}

@test "lib: community_move_entry moves entry" {
  community_create mvlsrc >/dev/null
  community_create mvldst >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"move test"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" mvlsrc testprofile.task.mvl-001 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run community_move_entry "$eid" mvlsrc mvldst
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_modify_entry updates tags" {
  community_create modlib >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"modify test"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" modlib testprofile.task.ml-001 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run community_modify_entry "$eid" --tags "a,b"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "lib: community_mark_comment_copied marks copied" {
  community_create cplib >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"copy test"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" cplib testprofile.task.cp-lib "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  cmt_out="$(python3 "$STORE_PY" add-comment "$WW_BASE" "$eid" "copy lib test")"
  cid="$(echo "$cmt_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['comment_id'])")"
  run community_mark_comment_copied "$cid"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}
