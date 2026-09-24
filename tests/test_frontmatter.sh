#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Prints the YAML frontmatter block only (POSIX awk; works on BSD and GNU).
frontmatter() { awk 'NR==1 && $0!="---"{exit 1} NR>1 && $0=="---"{exit} NR>1{print}' "$1"; }
field() { frontmatter "$1" | awk -v k="$2" -F': *' '$1==k{sub(/^[^:]*: */,""); print; exit}'; }

files="$(ls "$ROOT"/agents/*.md "$ROOT"/skills/*/SKILL.md 2>/dev/null)"
[ -n "$files" ] && pass || fail "at least one agent or skill exists"

for f in $files; do
  rel="${f#$ROOT/}"
  head -n1 "$f" | grep -q '^---$' && pass || fail "$rel starts with frontmatter"
  [ -n "$(field "$f" name)" ] && pass || fail "$rel has name"
  [ -n "$(field "$f" description)" ] && pass || fail "$rel has description"
  model="$(field "$f" model)"
  # Sonnede runs entirely on Sonnet 5; only an explicit inherit is allowed beside it.
  case "$model" in ""|claude-sonnet-5|inherit) pass ;; *) fail "$rel model '$model' not allowed" ;; esac
  effort="$(field "$f" effort)"
  case "$effort" in ""|low|medium|high|xhigh|max) pass ;; *) fail "$rel effort '$effort' not allowed" ;; esac
done

# Skills and agents that must exist (extended by later tasks)
assert_file_exists "$ROOT/skills/record-evidence/SKILL.md" "record-evidence skill"
assert_file_exists "$ROOT/skills/define-requirements/SKILL.md" "define-requirements skill"
assert_file_exists "$ROOT/skills/orchestrate/SKILL.md" "orchestrate skill"
for a in researcher designer design-reviewer planner implementer reviewer-quality reviewer-security reviewer-spec reviewer-tests triage doc-writer; do
  assert_file_exists "$ROOT/agents/$a.md" "agent $a"
done

test_summary
