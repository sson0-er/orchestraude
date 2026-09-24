#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

# default convention: scripts/verify.sh under cwd
mkdir -p "$TMP/proj/scripts"
cp "$ROOT/tests/fixtures/verify-pass.sh" "$TMP/proj/scripts/verify.sh"
"$ROOT/bin/orchestraude-verify" --log "$TMP/pass.log" --cwd "$TMP/proj"
assert_exit 0 $? "passing verify exits 0"
assert_contains "$(cat "$TMP/pass.log")" "coverage: 92%" "stdout captured in log"

# failure propagates, stderr also captured
cp "$ROOT/tests/fixtures/verify-fail.sh" "$TMP/proj/scripts/verify.sh"
"$ROOT/bin/orchestraude-verify" --log "$TMP/fail.log" --cwd "$TMP/proj"
assert_exit 1 $? "failing verify exits 1"
assert_contains "$(cat "$TMP/fail.log")" "test_foo FAILED" "stderr captured in log"

# override via env
ORCHESTRAUDE_VERIFY_CMD="$ROOT/tests/fixtures/verify-pass.sh" "$ROOT/bin/orchestraude-verify" --log "$TMP/env.log" --cwd "$TMP"
assert_exit 0 $? "ORCHESTRAUDE_VERIFY_CMD override works"

# missing script
mkdir -p "$TMP/empty"
"$ROOT/bin/orchestraude-verify" --log "$TMP/missing.log" --cwd "$TMP/empty" 2>/dev/null
assert_exit 3 $? "missing verify script exits 3"

# missing script with nested log directory (log directory must be created before exit path)
"$ROOT/bin/orchestraude-verify" --log "$TMP/nested/dir/missing.log" --cwd "$TMP/empty" 2>/dev/null
assert_exit 3 $? "missing verify script with nested log dir exits 3"
assert_file_exists "$TMP/nested/dir/missing.log" "log file created even when parent dir missing"
assert_contains "$(cat "$TMP/nested/dir/missing.log")" "verify script not found" "error message captured in nested log"

# missing option value exits 2
"$ROOT/bin/orchestraude-verify" --log 2>/dev/null
assert_exit 2 $? "missing --log value exits 2"

test_summary
