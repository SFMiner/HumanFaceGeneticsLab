#!/bin/bash
# Run every headless test suite (tests/**/test_*.gd) under the project's autoloads.
# Usage: ./tests/run_all_tests.sh
# Set GODOT to the Godot 4.5 binary if it is not `godot` on PATH, e.g.
#   GODOT=../../Godot_v4.5-stable_win64.exe ./tests/run_all_tests.sh
# A suite fails on a non-zero exit code or on any "SCRIPT ERROR" in its output (a script error inside a test
# does not change the exit code by itself).

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1

if ! command -v "$GODOT" &> /dev/null; then
	echo "ERROR: Godot not found ($GODOT). Set GODOT to the Godot 4.5 binary."
	exit 1
fi

# Register class_names (KeyboardNav, FocusRing, ...) so the scripts compile
"$GODOT" --headless --path . --editor --quit-after 250 > /dev/null 2>&1

echo "Running Human Face Genetics Tests"
echo "=========================="

PASSED=0
FAILED=0
FAILED_NAMES=()
OUT="$(mktemp)"

for suite in $(find tests -name 'test_*.gd' | sort); do
	echo ""
	echo "--- $suite"
	timeout 120 "$GODOT" --headless --path . --script "$suite" 2>&1 | tee "$OUT"
	CODE=${PIPESTATUS[0]}
	if [ "$CODE" -eq 0 ] && ! grep -q "SCRIPT ERROR" "$OUT"; then
		((PASSED++))
	else
		((FAILED++))
		FAILED_NAMES+=("$suite")
	fi
done
rm -f "$OUT"

echo ""
echo "=========================="
echo "Overall Results: $PASSED suites passed, $FAILED failed"
for name in "${FAILED_NAMES[@]}"; do
	echo "  FAILED: $name"
done
echo "=========================="

[ "$FAILED" -eq 0 ]
