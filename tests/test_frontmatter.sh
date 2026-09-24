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
  effort="$(field "$f" effort)"
  case "$effort" in ""|low|medium|high|xhigh|max) pass ;; *) fail "$rel effort '$effort' not allowed" ;; esac
done

# Skills and agents that must exist (extended by later tasks)
assert_file_exists "$ROOT/skills/record-evidence/SKILL.md" "record-evidence skill"
assert_file_exists "$ROOT/skills/define-requirements/SKILL.md" "define-requirements skill"
assert_file_exists "$ROOT/skills/orchestrate/SKILL.md" "orchestrate skill"

# The Opus/Sonnet split is the point of this plugin, so each role's model and
# effort is pinned here: a change must be deliberate, not a stray edit.
while read -r agent model effort; do
  f="$ROOT/agents/$agent.md"
  assert_file_exists "$f" "agent $agent"
  [ -e "$f" ] || continue
  assert_eq "$model" "$(field "$f" model)" "$agent model"
  assert_eq "$effort" "$(field "$f" effort)" "$agent effort"
done <<'EOF'
researcher        claude-sonnet-5 medium
designer          claude-opus-5-5 high
design-reviewer   claude-opus-5-5 high
planner           claude-opus-5-5 high
implementer       claude-sonnet-5 xhigh
reviewer-quality  claude-sonnet-5 high
reviewer-security claude-opus-5-5 high
reviewer-spec     claude-opus-5-5 high
reviewer-tests    claude-sonnet-5 medium
triage            claude-opus-5-5 medium
doc-writer        claude-sonnet-5 low
EOF
assert_eq 11 "$(ls "$ROOT"/agents/*.md | wc -l | tr -d ' ')" "every agent has a pinned model"

test_summary
