#!/usr/bin/env bash
# The prompts name agents, skills, commands and plugin files by string. Nothing
# else fails when one of them is renamed or removed, so the names are checked here.
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

refs() { grep -rhoE "$1" "$ROOT/skills" "$ROOT/agents" | sort -u; }

names="$(refs 'orchestraude:[a-z][a-z-]*')"
[ -n "$names" ] && pass || fail "the prompts reference at least one orchestraude: agent or skill"
for ref in $names; do
  name="${ref#orchestraude:}"
  if [ -e "$ROOT/agents/$name.md" ] || [ -e "$ROOT/skills/$name/SKILL.md" ]; then pass
  else fail "$ref is referenced but is neither an agent nor a skill"; fi
done

commands="$(refs 'orchestraude-[a-z][a-z-]*')"
[ -n "$commands" ] && pass || fail "the prompts reference at least one orchestraude- command"
for cmd in $commands; do
  [ -x "$ROOT/bin/$cmd" ] && pass || fail "$cmd is referenced but bin/$cmd is missing or not executable"
done
# The other direction: a command no prompt mentions is never run.
for f in "$ROOT"/bin/*; do
  cmd="$(basename "$f")"
  case " $(echo $commands) " in
    *" $cmd "*) pass ;;
    *) fail "bin/$cmd is not referenced by any skill or agent" ;;
  esac
done

paths="$(refs '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+')"
[ -n "$paths" ] && pass || fail "the prompts reference at least one plugin file"
for ref in $paths; do
  rel="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  rel="${rel%.}"   # a sentence-ending period is not part of the path
  [ -e "$ROOT/$rel" ] && pass || fail "$ref is referenced but $rel does not exist"
done

# Skills an agent preloads through its frontmatter.
for f in "$ROOT"/agents/*.md; do
  for skill in $(awk -F': *' '$1=="skills"{print $2; exit}' "$f" | tr -d '[],'); do
    [ -e "$ROOT/skills/$skill/SKILL.md" ] && pass || fail "$(basename "$f") preloads the missing skill $skill"
  done
done

# Files a skill points to with ${CLAUDE_SKILL_DIR}, and the other direction:
# a file next to SKILL.md that it never names is never read.
for skill in "$ROOT"/skills/*/SKILL.md; do
  dir="$(dirname "$skill")"
  for ref in $(grep -oE '\$\{CLAUDE_SKILL_DIR\}/[A-Za-z0-9_./-]+' "$skill" | sort -u); do
    rel="${ref#\$\{CLAUDE_SKILL_DIR\}/}"
    [ -e "$dir/$rel" ] && pass || fail "${skill#$ROOT/} points to the missing file $rel"
  done
  for f in "$dir"/*.md; do
    name="$(basename "$f")"
    [ "$name" = "SKILL.md" ] && continue
    grep -qF "\${CLAUDE_SKILL_DIR}/$name" "$skill" && pass || fail "${f#$ROOT/} is not referenced from its SKILL.md"
  done
done

# After context compaction Claude Code re-attaches only the first 5,000 tokens
# of an invoked skill. This file measured 2.7 bytes per token (input-token
# difference of `claude -p` with and without it, 2026-11-10), so 11,000 bytes
# is about 4,100 tokens: under the limit with margin. The phases that do not
# have to stay in context live in the phase-*.md files next to it.
size="$(wc -c < "$ROOT/skills/orchestrate/SKILL.md" | tr -d ' ')"
[ "$size" -le 11000 ] && pass || fail "skills/orchestrate/SKILL.md is $size bytes; keep it at or under 11000"

test_summary
