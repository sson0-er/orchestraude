#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"
D="$TMP/docs/orchestraude/feat"

status() { "$ROOT/bin/orchestraude-status" feat --cwd "$TMP"; }
task() { printf -- '---\nid: %s\ndepends_on: []\nstatus: %s\nattempts: 0\n---\n# Task\n' "$1" "$2" > "$D/tasks/$1.md"; }

# Walks one feature through the whole flow; each step adds the one file or
# line that completes the phase, and the status must move on by exactly that.
assert_eq "next: phase-1 (requirements, gate 1)" "$(status)" "nothing exists yet"
"$ROOT/bin/orchestraude-init" feat --cwd "$TMP" >/dev/null
assert_eq "next: phase-1 (requirements, gate 1)" "$(status)" "requirements not approved yet"

printf 'Status: approved (2026-11-10)\n# Requirements: feat\n' > "$D/01-requirements.md"
assert_eq "next: phase-2 step 1 (research)" "$(status)" "gate 1 passed, no research"

echo "research" > "$D/02-research.md"
assert_eq "next: phase-2 step 2 (design)" "$(status)" "research done, no design"

mkdir -p "$D/03-design" && echo "design" > "$D/03-design/README.md"
assert_eq "next: phase-2 step 3 (open questions, design review, gate 2)" "$(status)" "design written, gate 2 not passed"

echo "- gate 2 approved 2026-11-10" >> "$D/gates.md"
assert_eq "next: phase-3 step 1 (plan)" "$(status)" "gate 2 passed, no plan"

echo "plan" > "$D/04-plan.md"
assert_eq "next: phase-3 step 1 (plan)" "$(status)" "a plan without task files is not finished"

task 01-a pending
task 02-b pending
assert_eq "next: phase-3 step 2 (gate 3)" "$(status)" "plan and tasks written, gate 3 not passed"

echo "- gate 3 approved 2026-11-10" >> "$D/gates.md"
assert_eq "next: phase-4 (pending tasks: 2)" "$(status)" "gate 3 passed, no task done"

# Per-task artifacts sit next to the task files and are not tasks themselves.
task 01-a done
echo "# Review findings" > "$D/tasks/01-a.findings.md"
echo "## Round 1" > "$D/tasks/01-a.findings.history.md"
assert_eq "next: phase-4 (pending tasks: 1)" "$(status)" "one task done; findings files are not counted as tasks"

task 02-b done
assert_eq "next: phase-4.9 (low-findings triage, gate 4)" "$(status)" "all tasks done, gate 4 not passed"

echo "- gate 4 approved 2026-11-10" >> "$D/gates.md"
assert_eq "next: phase-5 (documentation)" "$(status)" "gate 4 passed"

# Follow-up tasks appended after gate 4 go back to the task loop, and from
# there straight to phase 5: gate 4 is on record, so no second triage.
task 03-c pending
assert_eq "next: phase-4 (pending tasks: 1)" "$(status)" "follow-up task pending after gate 4"
task 03-c done
assert_eq "next: phase-5 (documentation)" "$(status)" "follow-up tasks done, no second triage"

echo "- done 2026-11-10" >> "$D/gates.md"
assert_eq "next: done" "$(status)" "feature complete"

# A triage with no low findings records gate 4 as skipped; that counts as passed.
D2="$TMP/docs/orchestraude/other"
"$ROOT/bin/orchestraude-init" other --cwd "$TMP" >/dev/null
printf 'Status: approved (2026-11-10)\n' > "$D2/01-requirements.md"
echo "research" > "$D2/02-research.md"
mkdir -p "$D2/03-design" && echo "design" > "$D2/03-design/README.md"
echo "plan" > "$D2/04-plan.md"
printf -- '---\nid: 01-a\nstatus: done\n---\n' > "$D2/tasks/01-a.md"
printf -- '- gate 2 approved 2026-11-10\n- gate 3 approved 2026-11-10\n- gate 4 skipped 2026-11-10: no low findings\n' > "$D2/gates.md"
assert_eq "next: phase-5 (documentation)" "$("$ROOT/bin/orchestraude-status" other --cwd "$TMP")" "skipped gate 4 counts as passed"

# The Fable variant records its choice in the feature directory. The status
# repeats it on every call, so a resumed or compacted orchestrator still
# launches the design roles on that model.
D3="$TMP/docs/orchestraude/fab"
"$ROOT/bin/orchestraude-init" fab --cwd "$TMP" >/dev/null
echo "fable" > "$D3/design-model"
assert_eq "$(printf 'next: phase-1 (requirements, gate 1)\ndesign-model: fable')" "$("$ROOT/bin/orchestraude-status" fab --cwd "$TMP")" "a recorded design model is reported after the next step"
echo "something-else" > "$D3/design-model"
assert_eq "next: phase-1 (requirements, gate 1)" "$("$ROOT/bin/orchestraude-status" fab --cwd "$TMP")" "an unknown design model is not reported"

"$ROOT/bin/orchestraude-status" "Bad Slug" --cwd "$TMP" >/dev/null 2>&1
assert_exit 2 $? "invalid slug exits 2"
"$ROOT/bin/orchestraude-status" >/dev/null 2>&1
assert_exit 2 $? "missing slug exits 2"

test_summary
