#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

out="$("$ROOT/bin/orchestraude-init" user-login --cwd "$TMP")"
assert_exit 0 $? "init exits 0"
assert_file_exists "$TMP/docs/orchestraude/user-login/tasks" "feature tasks dir"
assert_file_exists "$TMP/docs/orchestraude/user-login/01-requirements.md" "requirements from template"
assert_file_exists "$TMP/docs/orchestraude/evidence/INDEX.md" "evidence index"
assert_file_exists "$TMP/docs/orchestraude/decisions" "decisions dir"
assert_contains "$(cat "$TMP/docs/orchestraude/review-policy.md" 2>/dev/null)" "## Accepted low findings" "review policy from template"
assert_contains "$(cat "$TMP/docs/orchestraude/user-login/01-requirements.md")" "# Requirements: user-login" "slug substituted"

# idempotent: existing content untouched
echo "edited" > "$TMP/docs/orchestraude/user-login/01-requirements.md"
echo "policy edited" > "$TMP/docs/orchestraude/review-policy.md"
"$ROOT/bin/orchestraude-init" user-login --cwd "$TMP"
assert_eq "edited" "$(cat "$TMP/docs/orchestraude/user-login/01-requirements.md")" "does not overwrite"
assert_eq "policy edited" "$(cat "$TMP/docs/orchestraude/review-policy.md")" "does not overwrite the review policy"

# A project without a verify script, typically a new repository, gets a
# placeholder so the flow can start. The placeholder must fail: one that
# passed would let every task through the verify gate unchecked.
[ -x "$TMP/scripts/verify.sh" ] && pass || fail "a placeholder verify script is created and is executable"
assert_contains "$out" "created scripts/verify.sh" "init says that it created the placeholder"
"$TMP/scripts/verify.sh" >/dev/null 2>"$TMP/placeholder.err"
assert_exit 1 $? "the placeholder fails"
assert_contains "$(cat "$TMP/placeholder.err")" "placeholder" "the placeholder says what it is"
"$ROOT/bin/orchestraude-verify" --log "$TMP/gate.log" --cwd "$TMP" 2>/dev/null
assert_exit 1 $? "the verify gate fails on the placeholder"

# The designer and the planner recognize the placeholder by its second line,
# and orchestraude-status reports it from the same line.
marker="orchestraude placeholder"
assert_contains "$(sed -n 2p "$ROOT/templates/verify.sh")" "$marker" "the second line of the placeholder carries the marker"
for f in agents/designer.md agents/design-reviewer.md agents/planner.md bin/orchestraude-status; do
  grep -q "$marker" "$ROOT/$f" && pass || fail "$f does not know the placeholder marker"
done

# A verify script the project already has is never replaced, whatever it is.
mkdir -p "$TMP/own/scripts"
printf '#!/bin/sh\nexit 0\n' > "$TMP/own/scripts/verify.sh"
out_own="$("$ROOT/bin/orchestraude-init" feat --cwd "$TMP/own")"
assert_eq "$(printf '#!/bin/sh\nexit 0')" "$(cat "$TMP/own/scripts/verify.sh")" "an existing verify script is left alone"
case "$out_own" in *"created scripts/verify.sh"*) fail "init must not claim to create an existing script" ;; *) pass ;; esac

# A project that names its own verify command does not want scripts/verify.sh.
mkdir -p "$TMP/custom"
ORCHESTRAUDE_VERIFY_CMD=tools/check.sh "$ROOT/bin/orchestraude-init" feat --cwd "$TMP/custom" >/dev/null
[ ! -e "$TMP/custom/scripts/verify.sh" ] && pass || fail "no placeholder when ORCHESTRAUDE_VERIFY_CMD is set"

# slug validation
"$ROOT/bin/orchestraude-init" "Bad Slug" --cwd "$TMP" 2>/dev/null
assert_exit 2 $? "rejects invalid slug"

test_summary
