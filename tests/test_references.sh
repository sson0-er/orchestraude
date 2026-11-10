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

# After context compaction Claude Code re-attaches only the first 5,000 tokens
# of an invoked skill. 16,000 bytes keeps the orchestrator's instructions under
# that with margin (about 4 bytes per token for this text; an estimate).
size="$(wc -c < "$ROOT/skills/orchestrate/SKILL.md" | tr -d ' ')"
[ "$size" -le 16000 ] && pass || fail "skills/orchestrate/SKILL.md is $size bytes; keep it at or under 16000"

test_summary
