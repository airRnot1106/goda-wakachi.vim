#!/usr/bin/env bash
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
cd "$root" || exit 1

source=internal/wakachi/segment.go
package=./internal/wakachi
corpus=internal/wakachi/testdata/fuzz

case $(go version 2>/dev/null) in
  *go1.26*) ;;
  *) echo 'mutants: run this inside the dev shell: nix develop -c <this script>' >&2; exit 64 ;;
esac

work=$(mktemp -d)
cp "$source" "$work/original.go"
restore() {
  cp "$work/original.go" "$source"
  for input in $(git ls-files --others --exclude-standard "$corpus" 2>/dev/null); do rm -f "$input"; done
  find "$corpus" -type d -empty -delete 2>/dev/null
  rm -rf "$work"
}
trap restore EXIT

seeds_catch() {
  go test "$package" -run "^$1\$" -count=1 >"$work/log" 2>&1
  grep -q "$2" "$work/log"
}

fuzzer_catches() {
  go test "$package" -run '^$' -fuzz "^$1\$" -fuzztime 50000x >"$work/log" 2>&1
  grep -q "$2" "$work/log"
}

bad=0
mutant() {
  local name=FuzzSegment$1 failure_message=$2 what_breaks=$3 sed_script=$4
  sed -e "$sed_script" "$work/original.go" >"$source"
  if cmp -s "$work/original.go" "$source"; then
    echo "STALE $name: the line to break is gone from $source ($what_breaks)"
    bad=$((bad + 1))
    return
  fi
  if seeds_catch "$name" "$failure_message" || fuzzer_catches "$name" "$failure_message"; then
    echo "CAUGHT $name: $what_breaks"
    grep -m 1 "$failure_message" "$work/log" | sed 's/^ */  /'
  else
    echo "MISSED $name: $what_breaks"
    tail -n 5 "$work/log" | sed 's/^/  /'
    bad=$((bad + 1))
  fi
}

mutant OnCharacters 'in the middle of a character\|outside the line' \
  'Last points after the last character' \
  's/last := tok.Position + len(tok.Surface) - size/last := tok.Position + len(tok.Surface) + size - size/'
mutant InOrder 'starts before byte' \
  'a joining token opens a second segment over the first' \
  's/segments\[len(segments)-1\].Last = last/segments = append(segments, Segment{Start: segments[len(segments)-1].Start, Last: last})/'
mutant WithoutWhitespace 'holds whitespace at byte' \
  'a whitespace token is treated as a word' \
  's/if strings.TrimSpace(tok.Surface) == "" {/if strings.TrimSpace(tok.Surface) == "\\x00" {/'
mutant CoversText 'in no segment' \
  'a joining token does not extend its segment' \
  's/segments\[len(segments)-1\].Last = last/_ = last/'

echo
if [ "$bad" -eq 0 ]; then
  echo 'mutants: every property failed on its broken variant'
else
  echo "mutants: $bad of 4 did not behave, see above"
  exit 1
fi
