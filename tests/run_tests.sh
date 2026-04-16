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

echo "Legna Compiler Test Suite v0.8"
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

# v0.5 features: AI-native I/O
run_test "emit_str" "tests/emit_str.legna" "$(printf '{"status":"ok"}')"
run_test "emit_int" "tests/emit_int.legna" "$(printf '{"count":42}')"

# v0.5 features: File I/O
run_test "close_fd" "tests/close_fd.legna" "$(printf 'ok')"

# v0.5 features: Concurrency
run_test "spawn_wait" "tests/spawn_wait.legna" "$(printf 'child\ndone')"

# v0.7 features: Large immediates
run_test "bignum" "tests/bignum.legna" "$(printf '100000\n100001\n1000000')"

# v0.7 features: Augmented assignment
run_test "augassign" "tests/augassign.legna" "$(printf '15\n12\n24')"

# v0.7 features: Arrays
run_test "array" "tests/array.legna" "$(printf '10 20 30')"
run_test "array_loop" "tests/array_loop.legna" "$(printf '30')"

# v0.7 features: String builtins
run_test "strlen" "tests/strlen.legna" "$(printf '5')"
run_test "charat" "tests/charat.legna" "$(printf '104 111')"
run_test "tonum" "tests/tonum.legna" "$(printf '123')"
run_test "bubblesort" "tests/bubblesort.legna" "$(printf '1 3 4 5 8')"

# v0.8 features: Multi-file compilation + import
run_test "import_math" "tests/import_math.legna" "$(printf '42\n7\n3\n1024\n10')"
run_test "import_string" "tests/import_string.legna" "$(printf '1\n1\n65\n104')"
run_test "import_multi" "tests/import_multi.legna" "$(printf '5\n1\n27')"
run_test "import_math2" "tests/import_math2.legna" "$(printf '1 0 -1\n4 12\n1 120 3628800\n0 1 55\n0 1 10 9\n0 1 1 0 1\n1 4\n3 2 1')"
run_test "import_string2" "tests/import_string2.legna" "$(printf '1 1 0\n1 1 0\n1 0 1 0\n1 1 0\n1 1 0\n0 10 15\n5 -1')"
run_test "import_bits" "tests/import_bits.legna" "$(printf '1 8 80 5 1\n1 0 10 8\n8 14 6\n0 3 8')"
run_test "import_conv" "tests/import_conv.legna" "$(printf '48 57 97 102\n0 10 15 -1\n48 49')"
run_test "import_algo" "tests/import_algo.legna" "$(printf '1\n1\n25 75\n50 0\n10 5050\n15\n7 7')"
run_test "import_check" "tests/import_check.legna" "$(printf '11/11')"
run_test "import_hash" "tests/import_hash.legna" "$(printf '1\n1\n1\n1')"
run_test "ffi_libc" "tests/ffi_libc.legna" "$(printf '42 5 1')"
run_test "ffi_mixed" "tests/ffi_mixed.legna" "$(printf '42 5 4 1')"
run_test "struct" "tests/struct.legna" "$(printf '25 30 100 120')"
run_test "method" "tests/method.legna" "$(printf '25 169 60')"
run_test "fnptr" "tests/fnptr.legna" "$(printf '10 15 20 30')"
run_test "bitwise" "tests/bitwise.legna" "$(printf '1 7 6 -1 16 4 15')"
run_test "switch" "tests/switch.legna" "$(printf 'two default expr')"
run_test "multiret" "tests/multiret.legna" "$(printf '3 2 7 42')"
run_test "stdlib" "tests/stdlib.legna" "$(printf '21 1 3 1 2 1 8')"
run_test "functional" "tests/functional.legna" "$(printf '10 2 1 0 2 4 6 8')"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "All tests passed!" || exit 1
