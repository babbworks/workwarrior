#!/usr/bin/env bats
# Installation System Tests
# Tests for install.sh, uninstall.sh, and installer-utils.sh

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export TEST_MODE=1
  export TEST_HOME="${BATS_TEST_TMPDIR}/home-$$"
  export HOME="$TEST_HOME"
  export WW_INSTALL_DIR="$TEST_HOME/ww"
  export WW_BASE="$WW_INSTALL_DIR"
  export PROFILES_DIR="$WW_INSTALL_DIR/profiles"

  mkdir -p "$TEST_HOME"

  # Create test shell RC files
  touch "$TEST_HOME/.bashrc"
  touch "$TEST_HOME/.zshrc"

  # Source the installer utilities
  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/installer-utils.sh"
}

teardown() {
  if [[ -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
}

# ============================================================================
# Dependency Checking Tests
# ============================================================================

@test "command_exists returns 0 for existing command" {
  run command_exists "bash"
  assert_success
}

@test "command_exists returns 1 for non-existent command" {
  run command_exists "nonexistent_command_12345"
  assert_failure
}

@test "check_dependencies returns 0 even with missing deps" {
  # check_dependencies should always succeed (just warn)
  run check_dependencies
  assert_success
}

# ============================================================================
# Shell Detection Tests
# ============================================================================

@test "detect_shell returns valid shell name" {
  run detect_shell
  assert_success
  # Should be bash, zsh, or unknown
  [[ "$output" == "bash" ]] || [[ "$output" == "zsh" ]] || [[ "$output" == "unknown" ]]
}

@test "get_shell_rc_files returns existing RC files" {
  run get_shell_rc_files
  assert_success
  # Should include at least one file
  assert_output --partial ".bashrc"
}

# ============================================================================
# Shell RC Configuration Tests
# ============================================================================

@test "add_ww_to_shell_rc adds configuration block" {
  run add_ww_to_shell_rc "$TEST_HOME/.bashrc" "ww"
  assert_success

  # Verify command-specific section marker was added
  run grep -F "# --- Workwarrior Installation (ww) ---" "$TEST_HOME/.bashrc"
  assert_success

  # Verify end marker was added
  run grep -F "# --- End Workwarrior Installation (ww) ---" "$TEST_HOME/.bashrc"
  assert_success
}

@test "add_ww_to_shell_rc is idempotent" {
  # Add twice
  add_ww_to_shell_rc "$TEST_HOME/.bashrc" "ww"
  add_ww_to_shell_rc "$TEST_HOME/.bashrc" "ww"

  # Count section markers - should only be 1
  local count
  count=$(grep -c "# --- Workwarrior Installation (ww) ---" "$TEST_HOME/.bashrc" || echo "0")
  assert_equal "$count" "1"
}

@test "remove_ww_from_shell_rc removes configuration" {
  # First add
  add_ww_to_shell_rc "$TEST_HOME/.bashrc" "ww"

  # Verify it was added
  run grep -F "# --- Workwarrior Installation (ww) ---" "$TEST_HOME/.bashrc"
  assert_success

  # Now remove
  run remove_ww_from_shell_rc "$TEST_HOME/.bashrc" "ww"
  assert_success

  # Verify it was removed
  run grep -F "# --- Workwarrior Installation (ww) ---" "$TEST_HOME/.bashrc"
  assert_failure
}

@test "remove_ww_from_shell_rc creates backup" {
  # Add config
  add_ww_to_shell_rc "$TEST_HOME/.bashrc" "ww"

  # Remove config
  remove_ww_from_shell_rc "$TEST_HOME/.bashrc" "ww"

  # Check backup was created
  run ls "$TEST_HOME/.bashrc.ww-backup."* 2>/dev/null
  assert_success
}

# ============================================================================
# Directory Structure Tests
# ============================================================================

@test "create_install_structure creates all directories" {
  run create_install_structure
  assert_success

  # Verify directories exist
  assert [ -d "$WW_INSTALL_DIR" ]
  assert [ -d "$WW_INSTALL_DIR/bin" ]
  assert [ -d "$WW_INSTALL_DIR/lib" ]
  assert [ -d "$WW_INSTALL_DIR/scripts" ]
  assert [ -d "$WW_INSTALL_DIR/services" ]
  assert [ -d "$WW_INSTALL_DIR/profiles" ]
  assert [ -d "$WW_INSTALL_DIR/resources" ]
  assert [ -d "$WW_INSTALL_DIR/functions" ]
}

@test "create_install_structure is idempotent" {
  # Create twice - should not fail
  run create_install_structure
  assert_success

  run create_install_structure
  assert_success
}

# ============================================================================
# Installation State Tests
# ============================================================================

@test "is_ww_installed returns 1 when not installed" {
  run is_ww_installed
  assert_failure
}

@test "is_ww_installed returns 0 when installed" {
  # Simulate installation
  mkdir -p "$WW_INSTALL_DIR/bin"
  touch "$WW_INSTALL_DIR/bin/ww"

  run is_ww_installed
  assert_success
}

@test "get_installed_version returns unknown when no VERSION file" {
  mkdir -p "$WW_INSTALL_DIR"

  run get_installed_version
  assert_success
  assert_output "unknown"
}

@test "get_installed_version returns version from VERSION file" {
  mkdir -p "$WW_INSTALL_DIR"
  echo "1.0.0" > "$WW_INSTALL_DIR/VERSION"

  run get_installed_version
  assert_success
  assert_output "1.0.0"
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "Full installation creates working structure" {
  # Create install structure
  create_install_structure

  # Configure shell
  add_ww_to_shell_rc "$TEST_HOME/.bashrc"

  # Create version file
  echo "1.0.0" > "$WW_INSTALL_DIR/VERSION"

  # Create ww command
  cat > "$WW_INSTALL_DIR/bin/ww" << 'EOF'
#!/usr/bin/env bash
echo "ww version 1.0.0"
EOF
  chmod +x "$WW_INSTALL_DIR/bin/ww"

  # Verify installation
  assert [ -f "$WW_INSTALL_DIR/bin/ww" ]
  assert [ -x "$WW_INSTALL_DIR/bin/ww" ]
  assert [ -f "$WW_INSTALL_DIR/VERSION" ]

  # Verify shell config
  run grep -F "ww-init.sh" "$TEST_HOME/.bashrc"
  assert_success
}

@test "Profile preservation during reinstall" {
  # Create initial structure
  create_install_structure

  # Create a profile
  mkdir -p "$WW_INSTALL_DIR/profiles/test-profile"
  echo "test data" > "$WW_INSTALL_DIR/profiles/test-profile/data.txt"

  # Verify profile exists
  assert [ -f "$WW_INSTALL_DIR/profiles/test-profile/data.txt" ]

  # Recreate structure (simulating reinstall)
  create_install_structure

  # Profile should still exist
  assert [ -f "$WW_INSTALL_DIR/profiles/test-profile/data.txt" ]
}
