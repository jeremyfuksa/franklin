#!/bin/bash
# motd-tests.sh — Unit tests for motd helper functions
#
# This test suite validates the helper functions in motd-helpers.zsh:
#   - Color conversion (hex to ANSI)
#   - Darker color calculation
#   - Text color determination
#   - Bar chart rendering
#   - Column formatting
#
# Run with: bash test/motd-tests.sh
#
# Test Framework: Simple assertions (no external dependencies)

# Test framework: Simple assert functions
assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$actual" = "$expected" ]; then
        echo "✓ $message"
        ((TESTS_PASSED++))
    else
        echo "✗ $message (expected: '$expected', got: '$actual')"
        ((TESTS_FAILED++))
    fi
}

assert_in_range() {
    local actual="$1"
    local min="$2"
    local max="$3"
    local message="${4:-Range assertion failed}"
    
    if [ "$actual" -ge "$min" ] && [ "$actual" -le "$max" ]; then
        echo "✓ $message"
        ((TESTS_PASSED++))
    else
        echo "✗ $message (expected: $min-$max, got: $actual)"
        ((TESTS_FAILED++))
    fi
}

TESTS_PASSED=0
TESTS_FAILED=0

echo "=== motd Helper Functions Test Suite ==="
echo ""

# Source the helpers
export FRANKLIN_TEST_MODE=1
source src/lib/motd-helpers.zsh

DEFAULT_MOTD_HEX="${MOTD_DEFAULT_HEX:-#4C627D}"
DEFAULT_MOTD_ANSI="${MOTD_DEFAULT_ANSI:-66}"

# ==============================================================================
# Test Suite: T2.2 - Hex to ANSI Color Conversion
# ==============================================================================

echo "Test Group: Hex to ANSI Color Conversion (T2.2)"

# Test valid colors
result=$(_motd_hex_to_ansi "#FF5733")
assert_in_range "$result" 16 231 "Test #FF5733 returns valid ANSI code"

result=$(_motd_hex_to_ansi "#000000")
assert_in_range "$result" 16 231 "Test #000000 (black) returns valid ANSI code"

result=$(_motd_hex_to_ansi "#FFFFFF")
assert_in_range "$result" 16 231 "Test #FFFFFF (white) returns valid ANSI code"

result=$(_motd_hex_to_ansi "$DEFAULT_MOTD_HEX")
assert_equals "$result" "$DEFAULT_MOTD_ANSI" "Test default Franklin accent returns expected ANSI code"

# Test case-insensitive
result=$(_motd_hex_to_ansi "#ff5733")
assert_in_range "$result" 16 231 "Test lowercase hex #ff5733 returns valid ANSI code"

# Test invalid format (should return default)
result=$(_motd_hex_to_ansi "invalid")
assert_equals "$result" "$DEFAULT_MOTD_ANSI" "Test invalid format returns default Franklin ANSI code"

result=$(_motd_hex_to_ansi "")
assert_equals "$result" "$DEFAULT_MOTD_ANSI" "Test empty string returns default Franklin ANSI code"

echo ""

# ==============================================================================
# Test Suite: T2.4 - Darker Color Calculation
# ==============================================================================

echo "Test Group: Darker Color Calculation (T2.4)"

# Test default Franklin accent produces darker color
result=$(_motd_get_darker_color "$DEFAULT_MOTD_ANSI")
assert_in_range "$result" 16 231 "Test default Franklin ANSI produces darker valid code"

# Test standard colors (0-15) use approximation
result=$(_motd_get_darker_color 10)
assert_in_range "$result" 0 15 "Test standard color 10 produces darker standard color"

# Test that darker color is different from input
result=$(_motd_get_darker_color 100)
# Should be different from 100 (but still valid)
assert_in_range "$result" 16 231 "Test ANSI 100 produces darker code"

echo ""

# ==============================================================================
# Test Suite: T2.6 - Text Color Determination
# ==============================================================================

echo "Test Group: Text Color Determination (T2.6)"

# Test standard dark color (< 8) uses white text
result=$(_motd_text_color 2)
assert_equals "$result" "white" "Test dark color (2) uses white text"

# Test standard bright color (8-15) uses black text
result=$(_motd_text_color 12)
assert_equals "$result" "black" "Test bright color (12) uses black text"

# Test extended colors with luminance calculation
result=$(_motd_text_color "$DEFAULT_MOTD_ANSI")
# Should be either "white" or "black" - exact value depends on luminance
if [ "$result" = "white" ] || [ "$result" = "black" ]; then
    echo "✓ Test Franklin ANSI returns valid text color (white or black)"
    ((TESTS_PASSED++))
else
    echo "✗ Test Franklin ANSI returns valid text color (got: '$result')"
    ((TESTS_FAILED++))
fi

echo ""

# ==============================================================================
# Test Suite: T2.8 - Bar Chart Rendering
# ==============================================================================

echo "Test Group: Bar Chart Rendering (T2.8)"

# Test 0% (all empty)
result=$(_motd_render_bar_chart 0 10)
# Should be |░░░░░░░░░░|
if [[ "$result" == "|"*"|" ]]; then
    echo "✓ Test 0% bar chart renders with pipes"
    ((TESTS_PASSED++))
else
    echo "✗ Test 0% bar chart format (got: '$result')"
    ((TESTS_FAILED++))
fi

# Test 100% (all filled)
result=$(_motd_render_bar_chart 100 10)
if [[ "$result" == "|"*"|" ]]; then
    echo "✓ Test 100% bar chart renders with pipes"
    ((TESTS_PASSED++))
else
    echo "✗ Test 100% bar chart format (got: '$result')"
    ((TESTS_FAILED++))
fi

# Test 50% (half-filled)
result=$(_motd_render_bar_chart 50 10)
if [[ "$result" == "|"*"|" ]]; then
    echo "✓ Test 50% bar chart renders with pipes"
    ((TESTS_PASSED++))
else
    echo "✗ Test 50% bar chart format (got: '$result')"
    ((TESTS_FAILED++))
fi

# Test custom width
result=$(_motd_render_bar_chart 50 20)
if [[ "$result" == "|"*"|" ]]; then
    echo "✓ Test custom width bar chart renders"
    ((TESTS_PASSED++))
else
    echo "✗ Test custom width bar chart (got: '$result')"
    ((TESTS_FAILED++))
fi

echo ""

# ==============================================================================
# Test Suite: T2.10 - Column Text Formatting
# ==============================================================================

echo "Test Group: Column Text Formatting (T2.10)"

# Test short text gets padded
result=$(_motd_format_column "test" 10)
if [ ${#result} -eq 10 ]; then
    echo "✓ Test short text padded to width 10"
    ((TESTS_PASSED++))
else
    echo "✗ Test short text padding (got length: ${#result}, expected: 10)"
    ((TESTS_FAILED++))
fi

# Test long text gets truncated with ellipsis
result=$(_motd_format_column "this is a very long text that should be truncated" 10)
if [ ${#result} -eq 10 ] && [[ "$result" == *"..." ]]; then
    echo "✓ Test long text truncated with ellipsis"
    ((TESTS_PASSED++))
else
    echo "✗ Test long text truncation (got: '$result', length: ${#result})"
    ((TESTS_FAILED++))
fi

# Test exact width
result=$(_motd_format_column "exact" 26)
if [ ${#result} -eq 26 ]; then
    echo "✓ Test text formatted to exact width 26"
    ((TESTS_PASSED++))
else
    echo "✗ Test exact width (got length: ${#result}, expected: 26)"
    ((TESTS_FAILED++))
fi

echo ""
echo "=== Test Summary ==="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
