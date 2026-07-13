#!/usr/bin/env bats
# test-deps-state.bats — TASK-LED-013, verifier finding F3.
#
# F3: the floor guard forked `hledger --version` on EVERY `ww` invocation. It tried to
# memoise with an exported flag, but `ww` is a fresh process each time and exports flow
# parent->child, never sibling->sibling — so the memo never fired.
#
# The fix is the `apt update` model: `ww deps check` probes and stamps; the guard reads
# the stamp. THE CENTRAL TEST HERE IS THE TRIPWIRE — it proves, by making the binary
# record its own invocation, that the guard forks NOTHING when the stamp is fresh.
# Asserting "it should be fast" would prove nothing.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_DEPS_MANIFEST="${REPO_ROOT}/config/dependencies.yaml"
  export WW_DEPS_STATE="${BATS_TEST_TMPDIR}/deps.json"

  # A fake hledger that RECORDS every invocation. Any fork leaves a trace.
  FAKEBIN="${BATS_TEST_TMPDIR}/bin"
  TRIPWIRE="${BATS_TEST_TMPDIR}/tripwire"
  mkdir -p "$FAKEBIN"
  cat > "${FAKEBIN}/hledger" <<EOF
#!/usr/bin/env bash
echo "invoked" >> "${TRIPWIRE}"
echo "hledger 1.52.1, linux-x86_64"
EOF
  chmod +x "${FAKEBIN}/hledger"

  source "${REPO_ROOT}/lib/deps-state.sh"
}

trips() { [[ -f "$TRIPWIRE" ]] && wc -l < "$TRIPWIRE" | tr -d ' ' || echo 0; }

# ── the stamp ────────────────────────────────────────────────────────────────

@test "refresh writes a stamp recording version, min, status and path" {
  PATH="${FAKEBIN}:$PATH" run deps_state_refresh
  [ "$status" -eq 0 ]
  [ -f "$WW_DEPS_STATE" ]
  run grep -q '"hledger"' "$WW_DEPS_STATE"
  [ "$status" -eq 0 ]

  PATH="${FAKEBIN}:$PATH" run deps_state_get hledger status
  [ "$output" = "ok" ]
  PATH="${FAKEBIN}:$PATH" run deps_state_get hledger version
  [ "$output" = "1.52.1" ]
}

@test "a below-floor tool is stamped below_floor, not ok" {
  cat > "${FAKEBIN}/hledger" <<'EOF'
#!/usr/bin/env bash
echo "hledger 1.25, linux-x86_64"
EOF
  chmod +x "${FAKEBIN}/hledger"
  PATH="${FAKEBIN}:$PATH" deps_state_refresh
  run deps_state_get hledger status
  [ "$output" = "below_floor" ]
}

# ── F3: THE TRIPWIRE. This is the whole point of the card's fix. ─────────────

@test "F3: guard forks ZERO subprocesses when the stamp is fresh" {
  PATH="${FAKEBIN}:$PATH" deps_state_refresh      # the one legitimate probe
  local after_refresh; after_refresh="$(trips)"
  [ "$after_refresh" -gt 0 ]                      # refresh SHOULD have probed

  rm -f "$TRIPWIRE"                               # reset the tripwire

  # Ten guard calls, simulating ten `ww hledger ...` invocations.
  for _ in $(seq 10); do
    PATH="${FAKEBIN}:$PATH" deps_require_floor hledger
  done

  # If the guard probed the binary even once, the tripwire file exists.
  [ "$(trips)" -eq 0 ]
}

@test "F3: guard self-heals with ONE probe when no stamp exists, then stops probing" {
  rm -f "$WW_DEPS_STATE" "$TRIPWIRE"

  PATH="${FAKEBIN}:$PATH" run deps_require_floor hledger
  [ "$status" -eq 0 ]
  [ -f "$WW_DEPS_STATE" ]                         # it stamped itself
  local first; first="$(trips)"
  [ "$first" -gt 0 ]                              # one self-healing probe

  rm -f "$TRIPWIRE"
  PATH="${FAKEBIN}:$PATH" deps_require_floor hledger
  PATH="${FAKEBIN}:$PATH" deps_require_floor hledger
  [ "$(trips)" -eq 0 ]                            # and never again
}

@test "stamp is invalidated when the manifest changes (a raised floor must not be stamped ok)" {
  PATH="${FAKEBIN}:$PATH" deps_state_refresh
  run deps_state_fresh
  [ "$status" -eq 0 ]

  # Raise the floor in a copy of the manifest.
  cp "${REPO_ROOT}/config/dependencies.yaml" "${BATS_TEST_TMPDIR}/m.yaml"
  sed -i 's/min_version: "1.52"/min_version: "9.99"/' "${BATS_TEST_TMPDIR}/m.yaml"
  export WW_DEPS_MANIFEST="${BATS_TEST_TMPDIR}/m.yaml"

  run deps_state_fresh
  [ "$status" -ne 0 ]      # the old stamp must NOT be trusted against a new manifest
}

@test "guard FAILS loudly (exit 2) when the stamp says below_floor" {
  cat > "${FAKEBIN}/hledger" <<'EOF'
#!/usr/bin/env bash
echo "hledger 1.25, linux-x86_64"
EOF
  chmod +x "${FAKEBIN}/hledger"
  PATH="${FAKEBIN}:$PATH" deps_state_refresh

  PATH="${FAKEBIN}:$PATH" run deps_require_floor hledger
  [ "$status" -eq 2 ]
}

@test "guard failure message is actionable and mentions refreshing the stamp" {
  cat > "${FAKEBIN}/hledger" <<'EOF'
#!/usr/bin/env bash
echo "hledger 1.25, linux-x86_64"
EOF
  chmod +x "${FAKEBIN}/hledger"
  PATH="${FAKEBIN}:$PATH" deps_state_refresh

  PATH="${FAKEBIN}:$PATH" run bash -c "source '${REPO_ROOT}/lib/deps-state.sh'; deps_require_floor hledger 2>&1"
  [[ "$output" == *"1.52"* ]]
  [[ "$output" == *"ww deps install hledger"* ]]
  [[ "$output" == *"ww deps check"* ]]
}

# ── advisory tools must never block ──────────────────────────────────────────

@test "an ADVISORY tool below its floor does NOT block (only hard floors refuse)" {
  cat > "${FAKEBIN}/task" <<'EOF'
#!/usr/bin/env bash
echo "task 1.0.0"
EOF
  chmod +x "${FAKEBIN}/task"
  PATH="${FAKEBIN}:$PATH" deps_state_refresh

  PATH="${FAKEBIN}:$PATH" run deps_require_floor task
  [ "$status" -eq 0 ]      # advisory: stale, but not fatal
}

@test "a missing tool is stamped 'missing', and refresh does NOT abort because of it" {
  # Regression: `command -v` on an absent tool returns 1, and a failing command
  # substitution inside an assignment fails the assignment — which aborted the whole
  # refresh under `set -e`. Recording that a tool is absent IS the job; it must never
  # be the thing that breaks the job.
  cat > "${BATS_TEST_TMPDIR}/m.yaml" <<'EOF'
schema: v1
tools:
  definitely-not-installed-xyz:
    min_version: "1.0"
    enforcement: advisory
    strategy: package
  hledger:
    min_version: "1.52"
    enforcement: hard
    strategy: static
EOF
  export WW_DEPS_MANIFEST="${BATS_TEST_TMPDIR}/m.yaml"

  PATH="${FAKEBIN}:$PATH" run deps_state_refresh
  [ "$status" -eq 0 ]                       # refresh SURVIVED the absent tool

  run deps_state_get definitely-not-installed-xyz status
  [ "$output" = "missing" ]

  # ...and the tools after it in the manifest were still stamped.
  PATH="${FAKEBIN}:$PATH" run deps_state_get hledger status
  [ "$output" = "ok" ]
}
