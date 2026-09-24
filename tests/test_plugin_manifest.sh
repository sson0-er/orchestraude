#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/.claude-plugin/plugin.json"

assert_file_exists "$MANIFEST" "manifest exists"
name="$(jq -r '.name' "$MANIFEST" 2>/dev/null)"
assert_eq "orchestraude" "$name" "manifest name"
desc_len="$(jq -r '.description | length' "$MANIFEST" 2>/dev/null)"
[ "${desc_len:-0}" -gt 0 ] && pass || fail "manifest has description"

test_summary
