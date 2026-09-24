#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

mkdir -p "$TMP/tasks"

cat > "$TMP/tasks/01-a.findings.quality.json" <<'EOF'
{"summary":"quality","findings":[
 {"severity":"low","title":"Duplicated helper.","location":"src/a.go:10","detail":"consolidate the two copies","evidence":""},
 {"severity":"low","title":"Overly clever one-liner","location":"src/b.go:5","detail":"simplify","evidence":""}
]}
EOF
cat > "$TMP/tasks/02-b.findings.quality.json" <<'EOF'
{"summary":"quality","findings":[
 {"severity":"low","title":"duplicated  helper","location":"src/c.go:20","detail":"","evidence":""}
]}
EOF
cat > "$TMP/tasks/02-b.findings.spec.json" <<'EOF'
{"summary":"spec","findings":[
 {"severity":"low","title":"design ambiguity: retention window","location":"","detail":"design is silent on the TTL","evidence":""}
]}
EOF
cat > "$TMP/tasks/03-c.findings.tests.json" <<'EOF'
{"summary":"tests","findings":[
 {"severity":"medium","title":"Missing boundary case","location":"t.go:1","detail":"add test","evidence":""},
 {"severity":"high","title":"Flaky test","location":"t.go:2","detail":"fix flake","evidence":""}
]}
EOF

line="$("$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/tasks" --out "$TMP/out.md")"
assert_exit 0 $? "triage exits 0"
assert_eq "raw: 4 merged: 3" "$line" "stdout summary line"

out="$(cat "$TMP/out.md")"
assert_contains "$out" "raw: 4, merged: 3, by role (merged): quality 2, security 0, spec 1, tests 0" "header counts"
assert_contains "$out" "L001" "id L001 assigned"
assert_contains "$out" "L002" "id L002 assigned"
assert_contains "$out" "L003" "id L003 assigned"
assert_contains "$out" "(2 occurrences; tasks: 01-a, 02-b)" "duplicated-helper merge across tasks"
assert_contains "$out" "## Pre-assigned B (design ambiguity)" "pre-assigned B section present"
assert_contains "$out" "design ambiguity: retention window" "B item rendered"
assert_contains "$out" "## To triage" "to-triage section present"
assert_contains "$out" "### quality" "quality role heading present"
case "$out" in
  *"### tests"*) fail "no ### tests heading (tests role contributed no lows)" ;;
  *) pass ;;
esac

# The B item's id (L003) appears exactly once: only under the B section,
# never repeated in the To-triage section (the merged summary lists no ids).
b_id_count="$(printf '%s' "$out" | grep -o 'L003' | wc -l | tr -d ' ')"
assert_eq "1" "$b_id_count" "B item id appears exactly once"

# Empty tasks dir: no findings files at all.
mkdir -p "$TMP/empty"
line2="$("$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/empty" --out "$TMP/out2.md")"
assert_exit 0 $? "empty dir exits 0"
assert_eq "raw: 0 merged: 0" "$line2" "empty dir stdout summary"
out2="$(cat "$TMP/out2.md")"
assert_contains "$out2" "raw: 0, merged: 0, by role (merged): quality 0, security 0, spec 0, tests 0" "empty dir header counts"
assert_contains "$out2" "No low findings." "empty dir body"

# Invalid findings JSON exits 2 and does not write the output file.
mkdir -p "$TMP/bad"
echo 'not json' > "$TMP/bad/01-x.findings.quality.json"
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/bad" --out "$TMP/out3.md" 2>/dev/null
assert_exit 2 $? "invalid findings json exits 2"
[ ! -e "$TMP/out3.md" ] && pass "output file not written on error" || fail "output file should not exist after error"

# Missing --out is a usage error.
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/tasks" 2>/dev/null
assert_exit 2 $? "missing --out exits 2"

# Missing --tasks-dir is a usage error.
"$ROOT/bin/orchestraude-findings-triage" --out "$TMP/out4.md" 2>/dev/null
assert_exit 2 $? "missing --tasks-dir exits 2"

# Nonexistent tasks dir exits 2.
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/does-not-exist" --out "$TMP/out5.md" 2>/dev/null
assert_exit 2 $? "nonexistent tasks dir exits 2"

# First non-empty detail wins: the first occurrence has an empty detail,
# the second (merged) occurrence has text, so the text must appear.
mkdir -p "$TMP/detail"
cat > "$TMP/detail/01-a.findings.quality.json" <<'EOF'
{"summary":"q","findings":[
 {"severity":"low","title":"Sparse helper","location":"a","detail":"","evidence":""}
]}
EOF
cat > "$TMP/detail/02-b.findings.quality.json" <<'EOF'
{"summary":"q","findings":[
 {"severity":"low","title":"Sparse helper","location":"b","detail":"here is the real detail","evidence":""}
]}
EOF
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/detail" --out "$TMP/detail-out.md" >/dev/null
detail_out="$(cat "$TMP/detail-out.md")"
assert_contains "$detail_out" "here is the real detail" "first non-empty detail is used"

# More than 5 unique locations: exactly 5 are shown, the rest are counted.
mkdir -p "$TMP/locs"
for i in 1 2 3 4 5 6 7; do
  cat > "$TMP/locs/0$i-t.findings.spec.json" <<EOF
{"summary":"s","findings":[{"severity":"low","title":"Many locations","location":"loc$i.go:1","detail":"d","evidence":""}]}
EOF
done
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/locs" --out "$TMP/locs-out.md" >/dev/null
locs_out="$(cat "$TMP/locs-out.md")"
assert_contains "$locs_out" "(+2 more)" "extra locations counted"
loc_line="$(printf '%s\n' "$locs_out" | grep 'Many locations')"
shown="$(printf '%s' "$loc_line" | grep -o 'loc[0-9]\.go:1' | wc -l | tr -d ' ')"
assert_eq "5" "$shown" "exactly 5 locations rendered"

# A finding with a null title must not crash the pipeline; the header stays
# well-formed (merged count is digits).
mkdir -p "$TMP/nulltitle"
cat > "$TMP/nulltitle/01-a.findings.quality.json" <<'EOF'
{"summary":"q","findings":[
 {"severity":"low","title":null,"location":"a","detail":"d","evidence":""}
]}
EOF
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/nulltitle" --out "$TMP/nulltitle-out.md" >/dev/null
assert_exit 0 $? "null title exits 0"
nulltitle_out="$(cat "$TMP/nulltitle-out.md")"
case "$nulltitle_out" in
  *"merged: "[0-9]*) pass "merged count is digits" ;;
  *) fail "merged count line malformed" ;;
esac

# An unknown role (not quality/security/spec/tests) is kept, not dropped:
# it gets its own header count and its own "### <role>" section.
mkdir -p "$TMP/perf"
cat > "$TMP/perf/01-a.findings.perf.json" <<'EOF'
{"summary":"p","findings":[
 {"severity":"low","title":"Slow query","location":"a","detail":"d","evidence":""}
]}
EOF
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/perf" --out "$TMP/perf-out.md" >/dev/null
perf_out="$(cat "$TMP/perf-out.md")"
assert_contains "$perf_out" "perf 1" "unknown role counted in header"
assert_contains "$perf_out" "### perf" "unknown role gets its own section"

# A title with an embedded newline renders on a single output line.
mkdir -p "$TMP/newline"
printf '{"summary":"q","findings":[{"severity":"low","title":"Multi\\nline title","location":"a","detail":"d","evidence":""}]}' \
  > "$TMP/newline/01-a.findings.quality.json"
"$ROOT/bin/orchestraude-findings-triage" --tasks-dir "$TMP/newline" --out "$TMP/newline-out.md" >/dev/null
assert_contains "$(cat "$TMP/newline-out.md")" "Multi line title" "embedded newline collapsed to one line"
newline_lines="$(grep -c '^- L' "$TMP/newline-out.md")"
assert_eq "1" "$newline_lines" "exactly one item line for the newline-title finding"

test_summary
