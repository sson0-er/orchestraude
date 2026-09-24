#!/usr/bin/env bash
# Minimal assertion helpers. No external test framework so the plugin
# stays dependency-free on a stock macOS (bash 3.2).
set -u

_PASS=0
_FAIL=0

fail() {
  echo "  FAIL: $1" >&2
  _FAIL=$((_FAIL + 1))
}

pass() {
  _PASS=$((_PASS + 1))
}

assert_eq() {
  if [ "$1" = "$2" ]; then pass; else fail "$3 (expected: '$1', actual: '$2')"; fi
}

assert_exit() {
  if [ "$1" -eq "$2" ]; then pass; else fail "$3 (expected exit $1, got $2)"; fi
}

assert_file_exists() {
  if [ -e "$1" ]; then pass; else fail "$2 (missing: $1)"; fi
}

assert_contains() {
  case "$1" in
    *"$2"*) pass ;;
    *) fail "$3 (did not find '$2')" ;;
  esac
}

# Each test file gets a private scratch dir; run.sh removes tests/.tmp.
make_tmp() {
  local d
  d="$(dirname "$0")/.tmp/$(basename "$0" .sh).$$"
  mkdir -p "$d"
  echo "$d"
}

test_summary() {
  echo "$(basename "$0"): $_PASS passed, $_FAIL failed"
  [ "$_FAIL" -eq 0 ]
}
