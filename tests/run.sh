#!/usr/bin/env bash
# Runs every tests/test_*.sh in order; exits non-zero if any file fails.
set -u
cd "$(dirname "$0")"
rm -rf .tmp
status=0
for t in test_*.sh; do
  echo "== $t"
  bash "$t" || status=1
done
rm -rf .tmp
exit $status
