#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

"$ROOT/bin/orchestraude-init" user-login --cwd "$TMP"
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

# slug validation
"$ROOT/bin/orchestraude-init" "Bad Slug" --cwd "$TMP" 2>/dev/null
assert_exit 2 $? "rejects invalid slug"

test_summary
