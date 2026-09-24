#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

cat > "$TMP/done.json" <<'JSON'
{"status":"done","summary":"added the parser","changed_files":["src/a.py"],"tests_added":["tests/test_a.py"],
 "dod_check":[{"item":"parses an empty file","met":true,"note":"tests/test_a.py::test_empty"}],
 "open_questions":[]}
JSON
line="$("$ROOT/bin/orchestraude-report-check" "$TMP/done.json")"
assert_exit 0 $? "valid report exits 0"
assert_eq "status: done open_questions: 0" "$line" "status line for a done report"

cat > "$TMP/blocked.json" <<'JSON'
{"status":"blocked","summary":"design is silent on the TTL","changed_files":[],"tests_added":[],
 "dod_check":[],"open_questions":["What is the TTL?","Which clock?"]}
JSON
line="$("$ROOT/bin/orchestraude-report-check" "$TMP/blocked.json")"
assert_exit 0 $? "blocked report is still valid"
assert_eq "status: blocked open_questions: 2" "$line" "status line for a blocked report"

echo 'not json' > "$TMP/bad.json"
"$ROOT/bin/orchestraude-report-check" "$TMP/bad.json" >/dev/null 2>&1
assert_exit 2 $? "invalid json exits 2"

# A missing required field is rejected, not silently defaulted.
cat > "$TMP/no-dod.json" <<'JSON'
{"status":"done","summary":"s","changed_files":[],"tests_added":[],"open_questions":[]}
JSON
"$ROOT/bin/orchestraude-report-check" "$TMP/no-dod.json" >/dev/null 2>&1
assert_exit 2 $? "missing dod_check exits 2"

cat > "$TMP/bad-status.json" <<'JSON'
{"status":"partial","summary":"s","changed_files":[],"tests_added":[],"dod_check":[],"open_questions":[]}
JSON
"$ROOT/bin/orchestraude-report-check" "$TMP/bad-status.json" >/dev/null 2>&1
assert_exit 2 $? "unknown status value exits 2"

cat > "$TMP/bad-dod.json" <<'JSON'
{"status":"done","summary":"s","changed_files":[],"tests_added":[],
 "dod_check":[{"item":"x","met":"yes","note":""}],"open_questions":[]}
JSON
"$ROOT/bin/orchestraude-report-check" "$TMP/bad-dod.json" >/dev/null 2>&1
assert_exit 2 $? "non-boolean dod_check.met exits 2"

cat > "$TMP/bad-files.json" <<'JSON'
{"status":"done","summary":"s","changed_files":[{"path":"a"}],"tests_added":[],"dod_check":[],"open_questions":[]}
JSON
"$ROOT/bin/orchestraude-report-check" "$TMP/bad-files.json" >/dev/null 2>&1
assert_exit 2 $? "non-string changed_files entry exits 2"

"$ROOT/bin/orchestraude-report-check" "$TMP/does-not-exist.json" >/dev/null 2>&1
assert_exit 2 $? "missing file exits 2"

"$ROOT/bin/orchestraude-report-check" >/dev/null 2>&1
assert_exit 2 $? "no argument exits 2"

"$ROOT/bin/orchestraude-report-check" "$TMP/done.json" extra >/dev/null 2>&1
assert_exit 2 $? "extra argument exits 2"

test_summary
