#!/usr/bin/env bash
# Types keys into a fresh editor that loads only goda.vim and this plugin, and
# writes what the editor showed before and after to
# artifacts/verify/<feature>/<name>.<editor>.json.
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: drive.sh <nvim|vim> <feature> --name <name> [options] -- <line>...

  --name <name>     file name of the evidence, without spaces
  --keys <keys>     keys to type, in the notation of a Vim "string" ("\<Esc>")
  --cursor <l,c>    line and byte column to start from, both from 1 (default 1,1)
  --unit <unit>     value of g:goda_wakachi#unit (default: unset)
  --pre <command>   Ex command to run before the keys
  --expr <expr>     Vim expression to evaluate after the keys
  <line>...         the lines of the buffer, at least one ('' for an empty line)
USAGE
  exit 64
}

[ $# -ge 2 ] || usage
editor=$1
feature=$2
shift 2

name='' keys='' cursor='1,1' unit='' pre='' expr=''
while [ $# -gt 0 ]; do
  case $1 in
    --name) name=$2; shift 2 ;;
    --keys) keys=$2; shift 2 ;;
    --cursor) cursor=$2; shift 2 ;;
    --unit) unit=$2; shift 2 ;;
    --pre) pre=$2; shift 2 ;;
    --expr) expr=$2; shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done
[ -n "$name" ] && [ $# -ge 1 ] || usage

case $editor in
  nvim) flags=(--headless) ;;
  vim) flags=(--not-a-term) ;;
  *) usage ;;
esac

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
out=$root/artifacts/verify/$feature/$name.$editor.json
mkdir -p "$(dirname "$out")"
rm -f "$out"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '%s\n' "$@" >"$work/lines.txt"

export GODA_WAKACHI_VERIFY_FEATURE=$feature
export GODA_WAKACHI_VERIFY_NAME=$name
export GODA_WAKACHI_VERIFY_LINES=$work/lines.txt
export GODA_WAKACHI_VERIFY_KEYS=$keys
export GODA_WAKACHI_VERIFY_CURSOR=$cursor
export GODA_WAKACHI_VERIFY_UNIT=$unit
export GODA_WAKACHI_VERIFY_PRE=$pre
export GODA_WAKACHI_VERIFY_EXPR=$expr
export GODA_WAKACHI_VERIFY_OUT=$out

nix run "$root#$editor" -- "${flags[@]}" -n -S "$here/driver.vim" >"$work/editor.log" 2>&1 &
pid=$!
for _ in $(seq 240); do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  echo "drive: $editor did not exit within 120 seconds, killed pid $pid" >&2
  exit 1
fi
if ! wait "$pid"; then
  echo "drive: $editor failed:" >&2
  cat "$work/editor.log" >&2
  exit 1
fi
[ -s "$out" ] || { echo "drive: $editor wrote no evidence" >&2; cat "$work/editor.log" >&2; exit 1; }

cat "$out"
if grep -q '"error":' "$out"; then
  echo "drive: the editor reported an error, see $out" >&2
  exit 2
fi
echo "evidence: $out" >&2
