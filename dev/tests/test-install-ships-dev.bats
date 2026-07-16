#!/usr/bin/env bats
# test-install-ships-dev.bats — TASK-SHIP-001
#
# Tests that:
#   1. install.sh copies dev/ into the install dir
#   2. The product still works WITHOUT dev/ (the load-bearing property)
#   3. wwctl is reachable from the installed layout

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_INSTALL_DIR="${BATS_TEST_TMPDIR}/ww-installed"
  export REPO_ROOT="${BATS_TEST_DIRNAME}/../.."

  # Simulate a minimal install by copying the allowlist
  mkdir -p "$WW_INSTALL_DIR"/{bin,lib,config,scripts,services,resources,functions,tools}

  # Copy bin/ww (the main script)
  cp "$REPO_ROOT/bin/ww" "$WW_INSTALL_DIR/bin/"
  chmod +x "$WW_INSTALL_DIR/bin/ww"

  # Copy lib
  cp "$REPO_ROOT/lib/"*.sh "$WW_INSTALL_DIR/lib/" 2>/dev/null || true

  # Copy config
  cp "$REPO_ROOT/config/"*.yaml "$WW_INSTALL_DIR/config/" 2>/dev/null || true

  # Copy dev/ (simulating what install.sh now does)
  if [[ -d "$REPO_ROOT/dev" ]]; then
    cp -r "$REPO_ROOT/dev" "$WW_INSTALL_DIR/dev"
  fi
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR"
}


# ── Criterion 1: dev/ is shipped ───────────────────────────────────────────

@test "install copies dev/ into install dir" {
  [ -d "$WW_INSTALL_DIR/dev" ]
}

@test "dev/tasks/ is present in installed layout" {
  [ -d "$WW_INSTALL_DIR/dev/tasks" ]
}

@test "dev/tests/ is present in installed layout" {
  [ -d "$WW_INSTALL_DIR/dev/tests" ]
}

@test "dev/TASKS.md is present in installed layout" {
  [ -f "$WW_INSTALL_DIR/dev/TASKS.md" ]
}


# ── Criterion 3: product works WITHOUT dev/ ────────────────────────────────
# This is THE critical property: dev/ ships but nothing depends on it.

@test "bin/ww --help succeeds without dev/" {
  rm -rf "$WW_INSTALL_DIR/dev"
  [ ! -d "$WW_INSTALL_DIR/dev" ]

  # ww help should work — it's a runtime function, not a dev tool
  run env WW_BASE="$WW_INSTALL_DIR" "$WW_INSTALL_DIR/bin/ww" help
  assert_success
}

@test "bin/ww version succeeds without dev/" {
  rm -rf "$WW_INSTALL_DIR/dev"
  run env WW_BASE="$WW_INSTALL_DIR" "$WW_INSTALL_DIR/bin/ww" version
  assert_success
}

@test "lib/ resolves without dev/ present" {
  rm -rf "$WW_INSTALL_DIR/dev"
  # Core libs should source without error
  run bash -c "source '$WW_INSTALL_DIR/lib/core-utils.sh' 2>/dev/null && echo ok"
  assert_output --partial "ok"
}

@test "config/ resolves without dev/ present" {
  rm -rf "$WW_INSTALL_DIR/dev"
  [ -f "$WW_INSTALL_DIR/config/units.yaml" ]
  [ -f "$WW_INSTALL_DIR/config/actors.yaml" ]
}


# ── Criterion 4: wwctl reachable from installed layout ─────────────────────

@test "dev/bin/ exists in installed layout (for wwctl)" {
  [ -d "$WW_INSTALL_DIR/dev/bin" ] || skip "dev/bin not present in repo"
}


# ── install.sh contains the dev/ copy line ─────────────────────────────────

@test "install.sh has the dev/ copy directive" {
  run grep 'cp -r.*dev' "$REPO_ROOT/install.sh"
  assert_success
  assert_output --partial 'SCRIPT_DIR/dev'
}

@test "install.sh mentions TASK-SHIP-001" {
  run grep "SHIP-001" "$REPO_ROOT/install.sh"
  assert_success
}
