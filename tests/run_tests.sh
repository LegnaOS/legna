#!/bin/bash
# Legna Compiler Test Suite v0.3
# Usage: ./tests/run_tests.sh

set -e
COMPILER=./legnac
PASS=0
FAIL=0
TOTAL=0

run_test() {
    local name="$1"
    local input="$2"
    local expected="$3"
    TOTAL=$((TOTAL + 1))

    if $COMPILER "$input" -o "/tmp/legna_test_$name" 2>/dev/null; then
        actual=$(/tmp/legna_test_$name 2>&1 || true)
        rm -f /tmp/legna_test_$name
        if [ "$actual" = "$expected" ]; then
            echo "  PASS  $name"
            PASS=$((PASS + 1))
        else
            echo "  FAIL  $name"
            echo "        expected: $(echo "$expected" | head -1)"
            echo "        got:      $(echo "$actual" | head -1)"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  FAIL  $name (compilation failed)"
        FAIL=$((FAIL + 1))
    fi
}

run_error_test() {
    local name="$1"
    local input="$2"
    TOTAL=$((TOTAL + 1))

    if $COMPILER "$input" -o "/tmp/legna_test_$name" 2>/dev/null; then
        rm -f /tmp/legna_test_$name
        echo "  FAIL  $name (should have failed)"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS  $name"
        PASS=$((PASS + 1))
    fi
}

echo "Legna Compiler Test Suite v0.4"
echo "=============================="
echo ""

# v0.1 compatibility
run_test "hello" "helloworld.legna" "hello, world"
run_test "multiline" "tests/multiline.legna" "$(printf 'hello\nworld')"
run_test "escape" "tests/escape.legna" "$(printf 'name:\tLegna\npath: C:\\legna\nsay "hello"')"
run_test "comments" "tests/comments.legna" "$(printf 'ok')"
run_test "empty_str" "tests/empty.legna" ""
run_test "multi" "tests/multi.legna" "$(printf 'one two three')"

# v0.2 features
run_test "vars" "tests/vars.legna" "$(printf '50\n40')"
run_test "ifelse" "tests/ifelse.legna" "$(printf 'big')"
run_test "while" "tests/while.legna" "$(printf '5 4 3 2 1 ')"
run_test "forloop" "tests/forloop.legna" "$(printf '0 1 2 3 4 ')"

# v0.3 features
run_test "elif" "tests/elif.legna" "$(printf 'mid')"
run_test "and_or" "tests/and_or.legna" "$(printf 'yes')"
run_test "break" "tests/break.legna" "$(printf '1 2 3 4 ')"
run_test "continue" "tests/continue.legna" "$(printf '1 3 5 ')"
run_test "forvar" "tests/forvar.legna" "$(printf '0 1 2 ')"
run_test "strvar" "tests/strvar.legna" "$(printf 'hello')"
run_test "fizzbuzz" "tests/fizzbuzz.legna" "$(printf '1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz')"

# v0.4 features
run_test "tabs" "tests/tabs.legna" "$(printf '0 1 2 ')"
run_test "fn" "tests/fn.legna" "$(printf '7')"
run_test "recursion" "tests/recursion.legna" "$(printf '3628800')"

# Error tests
run_error_test "no_file" "nonexistent.legna"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "All tests passed!" || exit 1
