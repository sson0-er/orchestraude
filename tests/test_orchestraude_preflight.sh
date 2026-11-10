#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(cd "$(make_tmp)" && pwd)"

mkdir -p "$TMP/proj/scripts"
git -C "$TMP/proj" init -q
cp "$ROOT/tests/fixtures/verify-pass.sh" "$TMP/proj/scripts/verify.sh"

"$ROOT/bin/orchestraude-preflight" --cwd "$TMP/proj" >/dev/null
assert_exit 0 $? "all prerequisites present exits 0"

# Verify script present but not executable: the gate could not run it.
chmod -x "$TMP/proj/scripts/verify.sh"
out="$("$ROOT/bin/orchestraude-preflight" --cwd "$TMP/proj")"
assert_exit 1 $? "non-executable verify script exits 1"
assert_contains "$out" "scripts/verify.sh" "the missing verify script is named"

# The override the verify gate honors is checked instead of the default.
ORCHESTRAUDE_VERIFY_CMD="$ROOT/tests/fixtures/verify-pass.sh" "$ROOT/bin/orchestraude-preflight" --cwd "$TMP/proj" >/dev/null
assert_exit 0 $? "ORCHESTRAUDE_VERIFY_CMD is checked instead of scripts/verify.sh"
chmod +x "$TMP/proj/scripts/verify.sh"

# Not a git repository. $TMP lives under this project's own repo, so use a
# directory outside any repo.
notgit="$(mktemp -d "${TMPDIR:-/tmp}/orchestraude-preflight-notgit.XXXXXX")"
trap 'rm -rf "$notgit"' EXIT
mkdir -p "$notgit/scripts"
cp "$ROOT/tests/fixtures/verify-pass.sh" "$notgit/scripts/verify.sh"
out="$("$ROOT/bin/orchestraude-preflight" --cwd "$notgit")"
assert_exit 1 $? "outside a git repository exits 1"
assert_contains "$out" "git repository" "the missing git repository is named"
rm -rf "$notgit"
trap - EXIT

# jq not on PATH (an empty PATH also hides git; only the jq line is asserted).
mkdir -p "$TMP/emptybin"
out="$(PATH="$TMP/emptybin" "$BASH" "$ROOT/bin/orchestraude-preflight" --cwd "$TMP/proj")"
assert_exit 1 $? "missing jq exits 1"
assert_contains "$out" "missing: jq" "missing jq is named"

"$ROOT/bin/orchestraude-preflight" --cwd >/dev/null 2>&1
assert_exit 2 $? "missing --cwd value exits 2"

test_summary
