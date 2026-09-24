#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(cd "$(make_tmp)" && pwd)"

"$ROOT/install.sh" --dest "$TMP/skills/orchestraude" >/dev/null
assert_exit 0 $? "install exits 0"
for p in .claude-plugin/plugin.json agents/researcher.md bin/orchestraude-init schemas/findings.schema.json skills/orchestrate/SKILL.md templates/task.md templates/design/README.md templates/design/interfaces/component.md README.md; do
  assert_file_exists "$TMP/skills/orchestraude/$p" "installed $p"
done
[ -x "$TMP/skills/orchestraude/bin/orchestraude-init" ] && pass || fail "bin scripts stay executable"
[ ! -e "$TMP/skills/orchestraude/tests" ] && pass || fail "tests not installed"
[ ! -e "$TMP/skills/orchestraude/docs" ] && pass || fail "docs not installed"
[ ! -e "$TMP/skills/orchestraude/templates/design.md" ] && pass || fail "old single-file design template is gone"

# Re-install replaces the previous copy and leaves no temp or backup dirs behind.
echo stale > "$TMP/skills/orchestraude/stale.txt"
"$ROOT/install.sh" --dest "$TMP/skills/orchestraude" >/dev/null
assert_exit 0 $? "re-install exits 0"
[ ! -e "$TMP/skills/orchestraude/stale.txt" ] && pass || fail "re-install replaces old copy"
assert_eq "orchestraude" "$(ls -A "$TMP/skills")" "no temp or backup dirs left beside the install"

# Never replace a directory that is not a previous install of this plugin.
mkdir -p "$TMP/other" && echo keep > "$TMP/other/keep.txt"
"$ROOT/install.sh" --dest "$TMP/other" 2>/dev/null
assert_exit 2 $? "refuses foreign directory"
assert_file_exists "$TMP/other/keep.txt" "foreign directory untouched"

# Default destination follows CLAUDE_CONFIG_DIR.
CLAUDE_CONFIG_DIR="$TMP/cfg" "$ROOT/install.sh" >/dev/null
assert_file_exists "$TMP/cfg/skills/orchestraude/.claude-plugin/plugin.json" "default dest under CLAUDE_CONFIG_DIR"

"$ROOT/install.sh" --dest 2>/dev/null
assert_exit 2 $? "missing --dest value is a usage error"

test_summary
