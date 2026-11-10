#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"
CLEAR="$ROOT/bin/orchestraude-report-clear"

tasks="$TMP/proj/docs/orchestraude/feat-a/tasks"
mkdir -p "$tasks"
echo '{}' > "$tasks/01-a.report.json"
echo 'task' > "$tasks/01-a.md"
echo 'log' > "$tasks/01-a.verify.log"

"$CLEAR" "$tasks/01-a.report.json"
assert_exit 0 $? "clearing an existing report exits 0"
[ ! -e "$tasks/01-a.report.json" ] && pass || fail "the report is deleted"
assert_file_exists "$tasks/01-a.md" "the task definition is kept"
assert_file_exists "$tasks/01-a.verify.log" "the verify log is kept"

# The first launch of a task has no report yet.
"$CLEAR" "$tasks/01-a.report.json"
assert_exit 0 $? "a missing report is not an error"

# The orchestrator passes the path relative to the project root.
echo '{}' > "$tasks/02-b.report.json"
(cd "$TMP/proj" && "$CLEAR" docs/orchestraude/feat-a/tasks/02-b.report.json)
assert_exit 0 $? "a relative path exits 0"
[ ! -e "$tasks/02-b.report.json" ] && pass || fail "the report named by a relative path is deleted"

# It deletes task reports and nothing else: the prompt runs it instead of
# `rm`, so it must not work as a general delete.
"$CLEAR" "$tasks/01-a.md" 2>/dev/null
assert_exit 2 $? "a task definition is refused"
assert_file_exists "$tasks/01-a.md" "the refused task definition is kept"

mkdir -p "$TMP/proj/build"
echo '{}' > "$TMP/proj/build/coverage.report.json"
err="$("$CLEAR" "$TMP/proj/build/coverage.report.json" 2>&1 >/dev/null)"
assert_exit 2 $? "a report outside docs/orchestraude is refused"
assert_file_exists "$TMP/proj/build/coverage.report.json" "the refused outside report is kept"
assert_contains "$err" "not a task report" "the refusal says why"

echo '{}' > "$TMP/proj/docs/orchestraude/feat-a/01-a.report.json"
"$CLEAR" "$TMP/proj/docs/orchestraude/feat-a/01-a.report.json" 2>/dev/null
assert_exit 2 $? "a report outside tasks/ is refused"
assert_file_exists "$TMP/proj/docs/orchestraude/feat-a/01-a.report.json" "the refused report outside tasks/ is kept"

"$CLEAR" 2>/dev/null
assert_exit 2 $? "no argument is a usage error"
"$CLEAR" "$tasks/01-a.report.json" "$tasks/02-b.report.json" 2>/dev/null
assert_exit 2 $? "two arguments are a usage error"

test_summary
