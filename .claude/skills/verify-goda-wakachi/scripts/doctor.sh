#!/usr/bin/env bash
# Says whether this checkout builds a plugin worth driving. Changes nothing in
# the repository.
set -euo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$root"

fail() {
  echo "doctor: FAIL: $1" >&2
  exit 1
}

dirty=''
git diff --quiet HEAD || dirty=' (uncommitted changes, included in the build)'
echo "revision: $(git rev-parse --short HEAD)$dirty"

untracked=$(git status --porcelain | grep '^??' || true)
if [ -n "$untracked" ]; then
  echo "warning: the flake cannot see untracked files, git add them first:"
  echo "$untracked"
fi

plugin=$(nix build .#vim-plugin --no-link --print-out-paths) || fail 'nix build .#vim-plugin'
echo "plugin: $plugin"
binary=$plugin/bin/goda-wakachi
[ -x "$binary" ] || fail "no binary at $binary"

answer=$(echo '{"method":"goda.plugins"}' | "$binary" --transport=jsonl)
echo "handshake: $answer"
case $answer in
  *'"wakachi"'*'"segment"'*) ;;
  *) fail 'the binary does not serve wakachi.segment' ;;
esac

for editor in nvim vim; do
  version=$(nix run ".#$editor" -- --version | head -n 1) || fail "nix run .#$editor"
  echo "$editor: $version"
done

echo 'doctor: OK'
