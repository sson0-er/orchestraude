#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/.claude-plugin/plugin.json"

assert_file_exists "$MANIFEST" "manifest exists"
name="$(jq -r '.name' "$MANIFEST" 2>/dev/null)"
assert_eq "orchestraude" "$name" "manifest name"
desc_len="$(jq -r '.description | length' "$MANIFEST" 2>/dev/null)"
[ "${desc_len:-0}" -gt 0 ] && pass || fail "manifest has description"
# A version set here pins users to it until it is bumped. Without one the commit
# SHA is the version, so every push reaches them.
assert_eq "false" "$(jq -r 'has("version")' "$MANIFEST" 2>/dev/null)" "plugin.json sets no version"

MARKET="$ROOT/.claude-plugin/marketplace.json"
assert_file_exists "$MARKET" "marketplace manifest exists"
assert_eq "orchestraude" "$(jq -r '.name' "$MARKET" 2>/dev/null)" "marketplace name"
[ -n "$(jq -r '.owner.name // empty' "$MARKET" 2>/dev/null)" ] && pass || fail "marketplace has owner.name"
assert_eq "$name" "$(jq -r '.plugins[0].name' "$MARKET" 2>/dev/null)" "marketplace entry names the plugin"
assert_eq "./" "$(jq -r '.plugins[0].source' "$MARKET" 2>/dev/null)" "marketplace entry points at the repo root"
assert_eq "false" "$(jq -r '.plugins[0] | has("version")' "$MARKET" 2>/dev/null)" "marketplace entry sets no version"

test_summary
