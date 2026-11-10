#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"
TASK="$ROOT/bin/orchestraude-task"

# A task file as the planner writes it. The body repeats the frontmatter
# keys on purpose: only the frontmatter may change.
make_task() {
  cat > "$1" <<EOF
---
id: 01-a
depends_on: []
status: pending
attempts: ${2:-0}
---
# Task 01: a

## Implementation notes
The fixture file starts with:
status: pending
attempts: 0

## History
(Append one entry per attempt: attempt number, outcome, main findings.)
EOF
}
frontmatter() { awk 'NR==1{next} $0=="---"{exit} {print}' "$1"; }

# --- done ---
make_task "$TMP/done.md"
"$TASK" done "$TMP/done.md"
assert_exit 0 $? "done exits 0"
assert_eq "id: 01-a
depends_on: []
status: done
attempts: 0" "$(frontmatter "$TMP/done.md")" "only the status line of the frontmatter changes"
assert_eq "1" "$(grep -c '^status: pending$' "$TMP/done.md")" "a status line in the body is left alone"
"$TASK" done "$TMP/done.md"
assert_exit 0 $? "done on a done task exits 0"
assert_eq "1" "$(grep -c '^status: done$' "$TMP/done.md")" "done twice leaves one status line"

# --- attempt ---
make_task "$TMP/att.md"
out="$("$TASK" attempt "$TMP/att.md" "verify failed")"
assert_exit 0 $? "attempt exits 0"
assert_eq "attempt: 1" "$out" "attempt prints the new number"
assert_contains "$(frontmatter "$TMP/att.md")" "attempts: 1" "attempts is incremented in the frontmatter"
assert_contains "$(frontmatter "$TMP/att.md")" "status: pending" "attempt leaves the status alone"
assert_eq "1" "$(grep -c '^attempts: 0$' "$TMP/att.md")" "an attempts line in the body is left alone"
out="$("$TASK" attempt "$TMP/att.md" "high: 0, medium: 2, low: 1")"
assert_eq "attempt: 2" "$out" "the second attempt is number 2"
assert_eq "- attempt 1: verify failed
- attempt 2: high: 0, medium: 2, low: 1" "$(grep '^- attempt' "$TMP/att.md")" "one History line per attempt, in order"
assert_eq "- attempt 2: high: 0, medium: 2, low: 1" "$(tail -n 1 "$TMP/att.md")" "the entry goes to the end of the History section"

# The entry belongs to the History section even when a section follows it.
make_task "$TMP/mid.md"
printf '\n## Notes\nkept\n' >> "$TMP/mid.md"
"$TASK" attempt "$TMP/mid.md" "verify failed" >/dev/null
hist="$(grep -n '^## History$' "$TMP/mid.md" | cut -d: -f1)"
entry="$(grep -n '^- attempt 1: verify failed$' "$TMP/mid.md" | cut -d: -f1)"
notes="$(grep -n '^## Notes$' "$TMP/mid.md" | cut -d: -f1)"
[ -n "$entry" ] && [ "$hist" -lt "$entry" ] && [ "$entry" -lt "$notes" ] && pass || fail "the entry sits between ## History ($hist) and the next heading ($notes), got line '$entry'"
assert_eq "kept" "$(tail -n 1 "$TMP/mid.md")" "the following section is kept"

# A task file without a History section still records the attempt.
printf -- '---\nid: 02-b\nstatus: pending\nattempts: 0\n---\n# Task 02: b\n' > "$TMP/nohist.md"
"$TASK" attempt "$TMP/nohist.md" "verify failed" >/dev/null
assert_exit 0 $? "attempt without a History section exits 0"
assert_eq "## History
- attempt 1: verify failed" "$(tail -n 2 "$TMP/nohist.md")" "a History section is added for the entry"

# A reason that spans lines must not break the one-line-per-attempt list.
make_task "$TMP/multi.md"
"$TASK" attempt "$TMP/multi.md" "high: 1,
medium: 0" >/dev/null
assert_eq "- attempt 1: high: 1, medium: 0" "$(grep '^- attempt' "$TMP/multi.md")" "a multi-line reason is written on one line"

# --- the limit: five fix attempts, then the user decides ---
make_task "$TMP/limit.md" 5
cp "$TMP/limit.md" "$TMP/limit.before"
out="$("$TASK" attempt "$TMP/limit.md" "verify failed")"
assert_exit 1 $? "a sixth attempt exits 1"
assert_contains "$out" "limit" "the refusal names the limit"
cmp -s "$TMP/limit.md" "$TMP/limit.before" && pass || fail "a refused attempt changes nothing"
out="$("$TASK" attempt --force "$TMP/limit.md" "verify failed")"
assert_exit 0 $? "--force goes past the limit"
assert_eq "attempt: 6" "$out" "--force counts the attempt"
assert_contains "$(frontmatter "$TMP/limit.md")" "attempts: 6" "--force increments attempts"
"$TASK" attempt "$TMP/limit.md" "verify failed" >/dev/null
assert_exit 1 $? "past the limit every further attempt is refused again"

# --- not a task file, bad usage ---
"$TASK" done "$TMP/absent.md" 2>/dev/null
assert_exit 2 $? "a missing file exits 2"
echo '# no frontmatter' > "$TMP/plain.md"
cp "$TMP/plain.md" "$TMP/plain.before"
"$TASK" done "$TMP/plain.md" 2>/dev/null
assert_exit 2 $? "done on a file without a frontmatter status exits 2"
"$TASK" attempt "$TMP/plain.md" "verify failed" 2>/dev/null
assert_exit 2 $? "attempt on a file without a frontmatter attempts exits 2"
cmp -s "$TMP/plain.md" "$TMP/plain.before" && pass || fail "a rejected file is not modified"
printf -- '---\nstatus: pending\nattempts: many\n---\n' > "$TMP/nan.md"
"$TASK" attempt "$TMP/nan.md" "verify failed" 2>/dev/null
assert_exit 2 $? "a non-numeric attempts value exits 2"
make_task "$TMP/usage.md"
"$TASK" attempt "$TMP/usage.md" 2>/dev/null
assert_exit 2 $? "attempt without a reason is a usage error"
"$TASK" attempt "$TMP/usage.md" "" 2>/dev/null
assert_exit 2 $? "an empty reason is a usage error"
"$TASK" reopen "$TMP/usage.md" 2>/dev/null
assert_exit 2 $? "an unknown subcommand is a usage error"
"$TASK" 2>/dev/null
assert_exit 2 $? "no arguments is a usage error"

test_summary
