#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(cd "$(make_tmp)" && pwd)"

# Set up a repo with one committed file, a .gitignore, and later some
# tracked/untracked/ignored changes to snapshot.
mkdir -p "$TMP/repo"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.email "test@example.com"
git -C "$TMP/repo" config user.name "Test"
echo "one" > "$TMP/repo/a.txt"
echo "*.log" > "$TMP/repo/.gitignore"
echo "kept" > "$TMP/repo/keep.log"
git -C "$TMP/repo" add a.txt .gitignore
git -C "$TMP/repo" add -f keep.log
git -C "$TMP/repo" commit -q -m "initial"

head_before="$(git -C "$TMP/repo" rev-parse HEAD)"

echo "two" > "$TMP/repo/a.txt"
echo "untracked" > "$TMP/repo/b.txt"
echo "ignored" > "$TMP/repo/c.log"

status_before="$(git -C "$TMP/repo" status --porcelain)"
sha1="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo")"
assert_exit 0 $? "snapshot exits 0"
case "$sha1" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
    pass ;;
  *) fail "snapshot did not print 40 hex chars: '$sha1'" ;;
esac

diffnames="$(git -C "$TMP/repo" diff --name-only HEAD "$sha1")"
assert_contains "$diffnames" "a.txt" "snapshot diff includes modified tracked file"
assert_contains "$diffnames" "b.txt" "snapshot diff includes untracked file"
case "$diffnames" in
  *c.log*) fail "snapshot diff must not include ignored file" ;;
  *) pass ;;
esac
# A force-added file that matches .gitignore is tracked and must survive the snapshot.
case "$diffnames" in
  *keep.log*) fail "ignored-but-tracked file must not appear as changed" ;;
  *) pass ;;
esac
assert_contains "$(git -C "$TMP/repo" ls-tree -r --name-only "$sha1")" "keep.log" "ignored-but-tracked file is kept in the snapshot"

head_after="$(git -C "$TMP/repo" rev-parse HEAD)"
assert_eq "$head_before" "$head_after" "HEAD unchanged after snapshot"

status_after="$(git -C "$TMP/repo" status --porcelain)"
assert_eq "$status_before" "$status_after" "working tree status unchanged after snapshot (byte-identical)"

# Change only b.txt and take a second snapshot: SHA differs, and the diff
# between the two snapshots is exactly the one changed file.
echo "changed again" > "$TMP/repo/b.txt"
sha2="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo")"
assert_exit 0 $? "second snapshot exits 0"
if [ "$sha1" != "$sha2" ]; then pass; else fail "second snapshot must differ from first"; fi
diffnames2="$(git -C "$TMP/repo" diff --name-only "$sha1" "$sha2")"
assert_eq "b.txt" "$diffnames2" "diff between snapshots is exactly the changed file"

# A subdirectory --cwd still captures the whole tree.
mkdir -p "$TMP/repo/sub" && echo "x" > "$TMP/repo/sub/x.txt"
sha_sub="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo/sub")"
tree_sub="$(git -C "$TMP/repo" ls-tree -r --name-only "$sha_sub")"
assert_contains "$tree_sub" "a.txt" "subdir cwd captures files outside the subdir"
assert_contains "$tree_sub" "sub/x.txt" "subdir cwd captures the subdir's untracked file"

# The command reviewers run in later rounds (snapshot-to-snapshot diff) must show
# changes to files that were never committed, which plain `git diff <sha>` cannot.
echo "def f(): return 1" > "$TMP/repo/impl.py"
s1="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo")"
echo "def f(): return 2" > "$TMP/repo/impl.py"
echo "x = 1" > "$TMP/repo/added.py"
s2="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo")"
expected="$(printf 'A\tadded.py\nM\timpl.py')"
assert_eq "$expected" "$(git -C "$TMP/repo" diff --name-status "$s1" "$s2")" "snapshot-to-snapshot diff shows added and modified untracked files"

# Orchestration artifacts under docs/orchestraude (reports, logs, findings) are
# written between snapshots; a reviewer's diff must not contain them.
mkdir -p "$TMP/repo/docs/orchestraude/feat/tasks"
a1="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo")"
echo "report" > "$TMP/repo/docs/orchestraude/feat/tasks/01-x.report.json"
echo "guide" > "$TMP/repo/docs/guide.md"
a2="$("$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo")"
assert_eq "docs/guide.md" "$(git -C "$TMP/repo" diff --name-only "$a1" "$a2")" "docs/orchestraude is left out of the snapshot diff, other docs are kept"

# Non-git directory exits 3. $TMP itself lives under this project's own
# repo (tests/.tmp/...), so use a directory outside any repo instead.
notgit="$(mktemp -d "${TMPDIR:-/tmp}/orchestraude-snapshot-notgit.XXXXXX")"
trap 'rm -rf "$notgit"' EXIT
"$ROOT/bin/orchestraude-snapshot" --cwd "$notgit" >/dev/null 2>&1
assert_exit 3 $? "non-git directory exits 3"
rm -rf "$notgit"
trap - EXIT

# Missing option value exits 2.
"$ROOT/bin/orchestraude-snapshot" --cwd >/dev/null 2>&1
assert_exit 2 $? "missing --cwd value exits 2"

# The private index directory is removed on exit (checked on one more run).
before="$(ls "${TMPDIR:-/tmp}" | grep -c '^orchestraude-snapshot\.')"
"$ROOT/bin/orchestraude-snapshot" --cwd "$TMP/repo" >/dev/null
after="$(ls "${TMPDIR:-/tmp}" | grep -c '^orchestraude-snapshot\.')"
assert_eq "$before" "$after" "no orchestraude-snapshot temp file leaked"

test_summary
