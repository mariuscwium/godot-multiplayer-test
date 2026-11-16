#!/usr/bin/env bash
# Run the headless test suite. Usage: tools/test.sh [filter]
# Re-imports first so new class_name scripts are registered.
G=${GODOT:-$HOME/godot-bin/Godot_v4.7.2-stable_linux.x86_64}
cd "$(dirname "$0")/.." || exit 1
"$G" --headless --path . --import >/dev/null 2>&1
"$G" --headless --path . -s tests/run_tests.gd -- "$@" 2>&1 | grep -vE "^(Godot Engine|$)"
exit "${PIPESTATUS[0]}"
