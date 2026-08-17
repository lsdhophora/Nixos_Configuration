#!/usr/bin/env bash
# Run the CPH test suite (TDD loop).
# Requires: emacs, clang++ (or: nix shell nixpkgs#emacs nixpkgs#clang --command ./run-tests.sh), node
set -euo pipefail
cd "$(dirname "$0")"

for bin in emacs clang++ node; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "missing: $bin (try: nix shell nixpkgs#emacs nixpkgs#clang --command ./run-tests.sh)"
    exit 1
  }
done

SCRATCH=$(mktemp -d /tmp/cph-tests-XXXXXX)
trap 'rm -rf "$SCRATCH"' EXIT
cp fixtures/problem.json "$SCRATCH/"
export CPH_TEST_DIR="$SCRATCH"

failures=0

run_batch() {
  local name=$1 log
  log="$SCRATCH/$name.log"
  if emacs -Q --batch -l "$name.el" >"$log" 2>&1; then
    echo "== $name: OK =="
    grep -E "^(PASS|FAIL)" "$log" || true
  else
    echo "== $name: FAILED (exit $?) =="
    grep -v "^$" "$log" || true
    failures=$((failures + 1))
  fi
  echo
}

run_batch test-1
run_batch test-4
run_batch test-5

echo "== userscript =="
if node test-userscript.mjs; then
  :
else
  failures=$((failures + 1))
fi
echo

if [ "$failures" -eq 0 ]; then
  echo "ALL TEST GROUPS PASSED"
else
  echo "$failures TEST GROUP(S) FAILED"
fi
exit "$failures"
