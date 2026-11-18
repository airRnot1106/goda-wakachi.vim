#!/usr/bin/env bash
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
cd "$root" || exit 1

execs=${1:-100000}
package=./internal/wakachi
corpus=internal/wakachi/testdata/fuzz
out=artifacts/verify-segment-offsets
covered=(internal/wakachi/segment.go go.mod go.sum)
targets=(OnCharacters InOrder WithoutWhitespace CoversText)

case $(go version 2>/dev/null) in
  *go1.26*) ;;
  *) echo 'check: run this inside the dev shell: nix develop -c <this script>' >&2; exit 64 ;;
esac

sync=$(sed -n 's/^Sync commit: `\([0-9a-f]*\)`.*/\1/p' "$here/../SKILL.md")
echo "go: $(go version)"
echo "revision: $(git rev-parse --short HEAD), sync commit: $sync"
if git diff --quiet "$sync" -- "${covered[@]}"; then
  echo 'covered code: unchanged since the sync commit'
else
  echo 'covered code: CHANGED since the sync commit, read "When the covered code changed" in SKILL.md'
  git diff --stat "$sync" -- "${covered[@]}"
fi
echo

mkdir -p "$out"
failed=0
for target in "${targets[@]}"; do
  name=FuzzSegment$target
  log=$out/$name.log
  if go test "$package" -run '^$' -fuzz "^$name\$" -fuzztime "${execs}x" >"$log" 2>&1; then
    echo "PASS $name ($execs runs)"
  else
    failed=$((failed + 1))
    echo "FAIL $name"
    grep -E 'segment_fuzz_test\.go:[0-9]+:|^(#|.*\.go:[0-9]+:[0-9]+:)' "$log" | sed 's/^ */  /'
  fi
  # The fuzzer writes a failing input next to the tests, where it would fail
  # every later go test. Keep it as evidence outside the package.
  for input in $(git ls-files --others --exclude-standard "$corpus/$name" 2>/dev/null); do
    mkdir -p "$out/counterexamples/$name"
    mv "$input" "$out/counterexamples/$name/"
    echo "  input: $out/counterexamples/$name/$(basename "$input")"
  done
done
find "$corpus" -type d -empty -delete 2>/dev/null

echo
if [ "$failed" -eq 0 ]; then
  echo 'check: every property held'
else
  echo "check: $failed of ${#targets[@]} properties failed, logs in $out"
  exit 1
fi
