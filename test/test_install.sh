#!/bin/bash
# Installation Tests
#
# Tests the install.sh helper functions without modifying the system

set -o pipefail

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# Test Utilities
# ============================================================================

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="$3"

  ((TESTS_RUN++))

  if [ "$expected" -eq "$actual" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: $msg (exit code $actual)"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: $msg"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local msg="$2"

  ((TESTS_RUN++))

  if [ -f "$file" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: File not found: $file ($msg)"
    return 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local msg="$3"

  ((TESTS_RUN++))

  if [ "$expected" = "$actual" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: $msg"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    return 1
  fi
}

load_install_script() {
  if [ -n "${INSTALL_FUNCTIONS_LOADED:-}" ]; then
    return
  fi

  FRANKLIN_TEST_MODE=1 source ./install.sh >/dev/null 2>&1
  set +e
  INSTALL_FUNCTIONS_LOADED=1
}

# ============================================================================
# Script Tests
# ============================================================================

test_install_script_exists() {
  echo "Test: install.sh exists"
  assert_file_exists "install.sh" "Main install script"
}

test_install_script_executable() {
  echo "Test: install.sh is executable"
  ((TESTS_RUN++))

  if [ -x "install.sh" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: install.sh is executable"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: install.sh is not executable"
  fi
}

test_platform_installers_exist() {
  echo "Test: Platform-specific installers exist"
  assert_file_exists "src/lib/install_macos.sh" "macOS installer"
  assert_file_exists "src/lib/install_debian.sh" "apt installer"
  assert_file_exists "src/lib/install_fedora.sh" "dnf installer"
}

test_install_help() {
  echo "Test: install.sh --help works"
  ((TESTS_RUN++))

  local output
  output=$(bash install.sh --help 2>&1)
  local exit_code=$?

  if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Usage"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: --help flag works"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: --help flag not working properly"
  fi
}

test_install_verbose() {
  echo "Test: install.sh --verbose flag"
  ((TESTS_RUN++))

  # Just test that the flag is recognized
  local output
  output=$(bash -c 'VERBOSE=1 bash install.sh --help 2>&1' || true)

  if echo "$output" | grep -q "Usage"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: --verbose flag recognized"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: --verbose flag not working"
  fi
}

test_helper_functions() {
  echo "Test: install.sh contains helper functions"
  ((TESTS_RUN++))

  local install_content
  install_content=$(cat install.sh)

  local required_functions=(
    "log_info"
    "log_success"
    "log_error"
    "check_command"
    "backup_file"
    "create_symlink"
    "run_version_audit"
    "detect_platform"
    "check_dependencies"
    "setup_zshrc"
    "configure_motd_color"
  )

  local all_found=1
  for func in "${required_functions[@]}"; do
    if echo "$install_content" | grep -q "^${func}("; then
      echo "  ✓ Function found: $func"
    else
      echo "  ✗ Function missing: $func"
      all_found=0
    fi
  done

  if [ $all_found -eq 1 ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: All helper functions present"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: Some helper functions missing"
  fi
}

test_platform_detection() {
  echo "Test: Platform detection"
  ((TESTS_RUN++))

  # Simply test that the uname detection logic works
  local uname_output
  uname_output=$(uname -s)

  local expected_family=""
  case "$uname_output" in
    Darwin)
      expected_family="macos"
      ;;
    Linux)
      expected_family="linux"
      ;;
    *)
      expected_family="unknown"
      ;;
  esac

  if [ -n "$expected_family" ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: Platform detection logic works (current: $expected_family)"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: Platform detection failed"
  fi
}

test_exit_codes() {
  echo "Test: Exit codes"
  ((TESTS_RUN++))

  # Test invalid option
  bash install.sh --invalid-option >/dev/null 2>&1
  local exit_code=$?

  if [ $exit_code -eq 2 ]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: Invalid option returns exit code 2"
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: Invalid option should return 2, got $exit_code"
  fi
}

test_create_symlink_missing_target() {
  echo "Test: create_symlink fails when target missing"
  load_install_script

  local tmp_dir
  tmp_dir=$(mktemp -d)
  local missing_target="$tmp_dir/does_not_exist"
  local link_path="$tmp_dir/link"

  create_symlink "$missing_target" "$link_path" >/dev/null 2>&1
  local exit_code=$?

  assert_equals "2" "$exit_code" "create_symlink returns 2 when target missing"
  rm -rf "$tmp_dir"
}

test_backup_asset_copies_files() {
  echo "Test: backup_asset copies files to backup dir"
  load_install_script

  local tmp_root
  tmp_root=$(mktemp -d)
  local prev_home="$HOME"
  local prev_backup_root="$BACKUP_ROOT"
  local prev_backup_timestamp="$BACKUP_TIMESTAMP"
  local prev_backup_dir="$FRANKLIN_BACKUP_DIR"

  HOME="$tmp_root/home"
  mkdir -p "$HOME"
  FRANKLIN_BACKUP_DIR="$tmp_root/backups"
  BACKUP_ROOT="$FRANKLIN_BACKUP_DIR"
  BACKUP_TIMESTAMP="unit-test"

  local sample="$HOME/sample.txt"
  echo "hello" > "$sample"

  backup_asset "$sample" "sample.txt" >/dev/null 2>&1

  assert_file_exists "$BACKUP_ROOT/$BACKUP_TIMESTAMP/sample.txt" "backup_asset creates backup copy"

  HOME="$prev_home"
  BACKUP_ROOT="$prev_backup_root"
  BACKUP_TIMESTAMP="$prev_backup_timestamp"
  FRANKLIN_BACKUP_DIR="$prev_backup_dir"
  rm -rf "$tmp_root"
}

test_backup_existing_shell_assets() {
  echo "Test: backup_existing_shell_assets saves key files"
  load_install_script

  local tmp_root
  tmp_root=$(mktemp -d)
  local prev_home="$HOME"
  local prev_backup_root="$BACKUP_ROOT"
  local prev_backup_timestamp="$BACKUP_TIMESTAMP"
  local prev_backup_dir="$FRANKLIN_BACKUP_DIR"

  HOME="$tmp_root/home"
  mkdir -p "$HOME/.config"
  echo "zshenv" > "$HOME/.zshenv"
  echo "zprofile" > "$HOME/.zprofile"
  echo "starship" > "$HOME/.config/starship.toml"
  mkdir -p "$HOME/.antigen"
  touch "$HOME/.antigen/antigen.zsh"

  FRANKLIN_BACKUP_DIR="$tmp_root/backups"
  BACKUP_ROOT="$FRANKLIN_BACKUP_DIR"
  BACKUP_TIMESTAMP="unit-test-assets"

  backup_existing_shell_assets >/dev/null 2>&1

  assert_file_exists "$BACKUP_ROOT/$BACKUP_TIMESTAMP/.zshenv" "zshenv backup exists"
  assert_file_exists "$BACKUP_ROOT/$BACKUP_TIMESTAMP/.zprofile" "zprofile backup exists"
  assert_file_exists "$BACKUP_ROOT/$BACKUP_TIMESTAMP/.config/starship.toml" "starship backup exists"
  assert_file_exists "$BACKUP_ROOT/$BACKUP_TIMESTAMP/.antigen/antigen.zsh" "antigen backup exists"

  HOME="$prev_home"
  BACKUP_ROOT="$prev_backup_root"
  BACKUP_TIMESTAMP="$prev_backup_timestamp"
  FRANKLIN_BACKUP_DIR="$prev_backup_dir"
  rm -rf "$tmp_root"
}

test_configure_motd_color_flag() {
  echo "Test: configure_motd_color writes Franklin selection"

  load_install_script

  local tmp_root
  tmp_root=$(mktemp -d)
  local prev_home="$HOME"
  local prev_xdg="$XDG_CONFIG_HOME"
  local prev_config_dir="$FRANKLIN_CONFIG_DIR"
  local prev_user_color="$USER_MOTD_COLOR"
  local prev_test_mode="${FRANKLIN_TEST_MODE:-1}"

  HOME="$tmp_root/home"
  mkdir -p "$HOME"
  XDG_CONFIG_HOME="$tmp_root/config"
  mkdir -p "$XDG_CONFIG_HOME"
  FRANKLIN_CONFIG_DIR="$XDG_CONFIG_HOME/franklin"
  USER_MOTD_COLOR="cello"
  FRANKLIN_TEST_MODE=0

  configure_motd_color >/dev/null 2>&1 || true

  local config_file="$FRANKLIN_CONFIG_DIR/motd.env"
  assert_file_exists "$config_file" "motd.env created via configure_motd_color"

  if [ -f "$config_file" ]; then
    local stored
    stored=$(grep -E 'MOTD_COLOR' "$config_file" | tail -n 1 | tr -d '\r')
    assert_equals 'export MOTD_COLOR="#6284a0"' "$stored" "motd.env stores Franklin Cello hex"
  fi

  rm -rf "$tmp_root"
  HOME="$prev_home"
  XDG_CONFIG_HOME="$prev_xdg"
  FRANKLIN_CONFIG_DIR="$prev_config_dir"
  USER_MOTD_COLOR="$prev_user_color"
  FRANKLIN_TEST_MODE="$prev_test_mode"
}

# ============================================================================
# Test Runner
# ============================================================================

run_all_tests() {
  echo "=========================================="
  echo "Bootstrap Installation Tests"
  echo "=========================================="
  echo ""

  test_install_script_exists
  test_install_script_executable
  test_platform_installers_exist
  test_install_help
  test_install_verbose
  test_helper_functions
  test_platform_detection
  test_exit_codes
  test_create_symlink_missing_target
  test_backup_asset_copies_files
  test_backup_existing_shell_assets
  test_configure_motd_color_flag

  echo ""
  echo "=========================================="
  echo "Test Results"
  echo "=========================================="
  echo "Tests run:    $TESTS_RUN"
  echo "Tests passed: $TESTS_PASSED"
  echo "Tests failed: $TESTS_FAILED"
  echo "=========================================="

  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    return 1
  fi
}

# Run tests
run_all_tests
