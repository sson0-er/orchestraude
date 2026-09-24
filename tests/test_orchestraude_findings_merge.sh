#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

cat > "$TMP/1-foo.findings.quality.json" <<'EOF'
{"summary":"quality ok-ish","findings":[
 {"severity":"medium","title":"Reimplements str.strip","location":"src/a.py:10","detail":"Use built-in","evidence":""}]}
EOF
cat > "$TMP/1-foo.findings.security.json" <<'EOF'
{"summary":"one high","findings":[
 {"severity":"high","title":"Unpinned dependency hash","location":"requirements.txt","detail":"Pin with --hash","evidence":"2026-09-08-pip-hash-mode"}]}
EOF
cat > "$TMP/1-foo.findings.tests.json" <<'EOF'
{"summary":"clean","findings":[]}
EOF

"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/merged.md" \
  "$TMP/1-foo.findings.quality.json" "$TMP/1-foo.findings.security.json" "$TMP/1-foo.findings.tests.json"
assert_exit 0 $? "merge without --fail-on exits 0"
md="$(cat "$TMP/merged.md")"
assert_contains "$md" "high: 1" "count high"
assert_contains "$md" "medium: 1" "count medium"
assert_contains "$md" "low: 0" "count low"
assert_contains "$md" "[security] Unpinned dependency hash" "role label and title"
assert_contains "$md" "evidence: 2026-09-08-pip-hash-mode" "evidence id rendered"
assert_contains "$md" "[quality] Reimplements str.strip" "quality finding rendered"

"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m2.md" --fail-on high "$TMP/1-foo.findings.security.json"
assert_exit 1 $? "--fail-on high fails when a high exists"
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m3.md" --fail-on high "$TMP/1-foo.findings.quality.json"
assert_exit 0 $? "--fail-on high passes with only medium"
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m4.md" --fail-on medium "$TMP/1-foo.findings.quality.json"
assert_exit 1 $? "--fail-on medium fails with a medium"

echo 'not json' > "$TMP/bad.json"
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m5.md" "$TMP/bad.json" 2>/dev/null
assert_exit 2 $? "invalid json exits 2"

# Test: missing option value exits 2
"$ROOT/bin/orchestraude-findings-merge" --out 2>/dev/null
assert_exit 2 $? "missing --out value exits 2"

# Test: missing .findings array exits 2 and doesn't write output
cat > "$TMP/no-findings.json" <<'EOF'
{"summary":"x"}
EOF
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m6.md" "$TMP/no-findings.json" "$TMP/1-foo.findings.quality.json" 2>/dev/null
assert_exit 2 $? "missing findings array exits 2"
[ ! -e "$TMP/m6.md" ] && pass "output file not written on error" || fail "output file should not exist after error"

# Test: invalid severity value exits 2 and doesn't write output
cat > "$TMP/bad-severity.json" <<'EOF'
{"summary":"x","findings":[
 {"severity":"critical","title":"t","location":"l","detail":"d","evidence":""}]}
EOF
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m8.md" "$TMP/bad-severity.json" 2>/dev/null
assert_exit 2 $? "invalid severity value exits 2"
[ ! -e "$TMP/m8.md" ] && pass "output file not written on invalid severity" || fail "output file should not exist after invalid severity"

# Test: non-object element in findings (listed first) still aborts even though
# a later, valid file is also on the command line
cat > "$TMP/bad-element.json" <<'EOF'
{"summary":"x","findings":["x"]}
EOF
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m9.md" "$TMP/bad-element.json" "$TMP/1-foo.findings.quality.json" 2>/dev/null
assert_exit 2 $? "non-object findings element exits 2"
[ ! -e "$TMP/m9.md" ] && pass "output file not written on non-object element" || fail "output file should not exist after non-object element"

# Test: temp file cleanup on error (no leak)
before="$(ls "${TMPDIR:-/tmp}" 2>/dev/null | grep -c '^orchestraude-findings\.' || echo 0)"
echo 'invalid json' > "$TMP/leak.json"
"$ROOT/bin/orchestraude-findings-merge" --out "$TMP/m7.md" "$TMP/leak.json" 2>/dev/null
after="$(ls "${TMPDIR:-/tmp}" 2>/dev/null | grep -c '^orchestraude-findings\.' || echo 0)"
assert_eq "$before" "$after" "temp file cleaned up on error"

test_summary
