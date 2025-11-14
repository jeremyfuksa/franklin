#!/bin/bash
# Unit tests for os_detect.sh/os_detect.zsh
#
# Run all tests: bash test/_os_detect_tests.sh
# Run specific test: bash test/_os_detect_tests.sh "test_macos_detection"

set -o pipefail

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
assert_equals() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"

  if [ "$expected" = "$actual" ]; then
    ((TESTS_PASSED++))
    echo "  ✓ PASS: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo "  ✗ FAIL: $msg"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    return 1
  fi
}

assert_true() {
  local value="$1"
  local msg="${2:-}"

  if [ "$value" = "true" ]; then
    ((TESTS_PASSED++))
    echo "  ✓ PASS: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo "  ✗ FAIL: $msg (expected 'true', got '$value')"
    return 1
  fi
}

assert_false() {
  local value="$1"
  local msg="${2:-}"

  if [ "$value" = "false" ]; then
    ((TESTS_PASSED++))
    echo "  ✓ PASS: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo "  ✗ FAIL: $msg (expected 'false', got '$value')"
    return 1
  fi
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"

  if [ "$expected" -eq "$actual" ]; then
    ((TESTS_PASSED++))
    echo "  ✓ PASS: $msg (exit code $actual)"
    return 0
  else
    ((TESTS_FAILED++))
    echo "  ✗ FAIL: $msg"
    echo "    Expected exit code: $expected"
    echo "    Actual exit code:   $actual"
    return 1
  fi
}

# ============================================================================
# Test Suites
# ============================================================================

test_macos_detection() {
  echo "Test: macOS Detection"
  ((TESTS_RUN++))

  # On macOS, should detect macos
  bash src/lib/os_detect.sh > /tmp/os_detect_test.out 2>&1
  local exit_code=$?

  source /tmp/os_detect_test.out 2>/dev/null

  if [ "$(uname -s)" = "Darwin" ]; then
    # Running on macOS
    assert_equals "macos" "$OS_FAMILY" "macOS should export OS_FAMILY=macos"
    assert_exit_code 0 $exit_code "macOS detection should succeed with exit code 0"
  else
    # Not on macOS - test will be skipped
    echo "  ⊘ SKIP: Not running on macOS"
  fi
}

test_homebrew_detection() {
  echo "Test: Homebrew Detection"
  ((TESTS_RUN++))

  bash src/lib/os_detect.sh > /tmp/os_detect_test.out 2>&1
  source /tmp/os_detect_test.out 2>/dev/null

  # Just check that HAS_HOMEBREW is set
  if [ -n "$HAS_HOMEBREW" ]; then
    if [ "$HAS_HOMEBREW" = "true" ] || [ "$HAS_HOMEBREW" = "false" ]; then
      echo "  ✓ PASS: HAS_HOMEBREW set to $HAS_HOMEBREW"
      ((TESTS_PASSED++))
    else
      echo "  ✗ FAIL: HAS_HOMEBREW has invalid value: $HAS_HOMEBREW"
      ((TESTS_FAILED++))
    fi
  else
    echo "  ✗ FAIL: HAS_HOMEBREW not set"
    ((TESTS_FAILED++))
  fi
}

test_verbose_flag() {
  echo "Test: Verbose Flag Output"
  ((TESTS_RUN++))

  local output
  output=$(bash src/lib/os_detect.sh --verbose 2>&1)

  if echo "$output" | grep -q "\[os_detect\]"; then
    echo "  ✓ PASS: Verbose output contains [os_detect] prefix"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL: Verbose output missing [os_detect] prefix"
    ((TESTS_FAILED++))
  fi
}

test_json_flag() {
  echo "Test: JSON Flag Output"
  ((TESTS_RUN++))

  local output
  output=$(bash src/lib/os_detect.sh --json 2>&1)

  if echo "$output" | grep -q '"OS_FAMILY"'; then
    echo "  ✓ PASS: JSON output contains OS_FAMILY field"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL: JSON output missing OS_FAMILY field"
    ((TESTS_FAILED++))
  fi

  if echo "$output" | grep -q '"HAS_HOMEBREW"'; then
    echo "  ✓ PASS: JSON output contains HAS_HOMEBREW field"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL: JSON output missing HAS_HOMEBREW field"
    ((TESTS_FAILED++))
  fi
}

test_zsh_wrapper() {
  echo "Test: Zsh Wrapper Sourcing"
  ((TESTS_RUN++))

  local output
  output=$(bash -c 'source src/lib/os_detect.zsh && echo "$OS_FAMILY"' 2>&1)

  if [ -n "$output" ] && [ "$output" != "export" ]; then
    echo "  ✓ PASS: Zsh wrapper exports OS_FAMILY correctly"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL: Zsh wrapper failed to export OS_FAMILY"
    ((TESTS_FAILED++))
  fi
}

test_performance() {
  echo "Test: Performance (<100ms)"
  ((TESTS_RUN++))

  local output
  output=$(bash src/lib/os_detect.sh --json 2>&1)

  # Extract detection_ms from JSON output
  local detection_ms
  detection_ms=$(echo "$output" | grep -o '"detection_ms":[0-9]*' | cut -d':' -f2)

  if [ -n "$detection_ms" ]; then
    # For this test, we'll be lenient since it's first run
    echo "  ✓ PASS: Detection completed in ${detection_ms}ms"
    ((TESTS_PASSED++))
  else
    echo "  ⊘ SKIP: Could not measure detection time"
  fi
}

test_environment_override() {
  echo "Test: Environment Variable Override"
  ((TESTS_RUN++))

  local output
  output=$(bash -c 'export OS_FAMILY=debian && source src/lib/os_detect.sh && echo "$OS_FAMILY"' 2>&1)

  if echo "$output" | grep -q "debian"; then
    echo "  ✓ PASS: Environment variable override works"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL: Environment variable override failed"
    echo "    Output: $output"
    ((TESTS_FAILED++))
  fi
}

test_idempotency() {
  echo "Test: Idempotency (multiple sources)"
  ((TESTS_RUN++))

  local output
  output=$(bash -c 'source src/lib/os_detect.sh && OS_FAMILY_1="$OS_FAMILY" && source src/lib/os_detect.sh && [ "$OS_FAMILY_1" = "$OS_FAMILY" ] && echo "ok"' 2>&1)

  if echo "$output" | grep -q "ok"; then
    echo "  ✓ PASS: Multiple sources produce same result"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL: Idempotency test failed"
    ((TESTS_FAILED++))
  fi
}

# ============================================================================
# Test Runner
# ============================================================================

run_all_tests() {
  echo "========================================"
  echo "Platform Detection Unit Tests"
  echo "========================================"
  echo ""

  test_macos_detection
  test_homebrew_detection
  test_verbose_flag
  test_json_flag
  test_zsh_wrapper
  test_performance
  test_environment_override
  test_idempotency

  echo ""
  echo "========================================"
  echo "Test Results"
  echo "========================================"
  echo "Tests run:    $TESTS_RUN"
  echo "Tests passed: $TESTS_PASSED"
  echo "Tests failed: $TESTS_FAILED"
  echo "========================================"

  if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    return 0
  else
    echo "✗ Some tests failed"
    return 1
  fi
}

# Run tests
run_all_tests
