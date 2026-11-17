# Startup and fallback

The plugin starts its binary on the first motion that needs it, from `g:goda_wakachi#binary` or from `bin/` in the plugin directory. On a line with only ASCII characters the keys run the native motions and the binary is not needed.

## Sub-features

- `start-lazy` leaves the binary stopped until a motion needs it.
- `start-bundled` starts the binary bundled in the plugin directory.
- `start-binary-option` starts the binary named by `g:goda_wakachi#binary`.
- `fallback-ascii` runs the native motion on a line with only ASCII characters.

## How to get to it (user POV)

- Open a file and press `w` on a line with Japanese text.
- Set `let g:goda_wakachi#binary = '/path/to/goda-wakachi'` before the first motion.
- Press `w` on a line such as `hello world foo`.

## Driving it with drive.sh

Preconditions:

- The baseline preconditions of the README hold.
- `W` stands for `'私は学校に行きました。'`.
- For `start-binary-option`, `BIN` is the output of `echo "$(nix build .#goda-wakachi --no-link --print-out-paths)/bin/goda-wakachi"`.

- **start-lazy.** Open the buffer and type nothing. Run `drive.sh <editor> startup --name lazy-start --expr 'goda#plugins()' -- W`. `expr.value` is `{}`.
- **start-bundled.** Press `w`. Run `drive.sh <editor> startup --name bundled --keys w -- W`. `after.cursor` is `[1, 7]` and `plugins.wakachi` is a path that ends in `vimplugin-goda-wakachi.vim-0.1.0/bin/goda-wakachi`.
- **start-binary-option.** Set the option, then press `w`. Run `drive.sh <editor> startup --name binary-option --pre "let g:goda_wakachi#binary = 'BIN'" --keys w -- W`. `after.cursor` is `[1, 7]` and `plugins.wakachi` equals `BIN`.
- **fallback-ascii.** Press `w` on an ASCII line. Run `drive.sh <editor> startup --name ascii --keys w -- 'hello world foo'`. `after.cursor` is `[1, 7]` and `plugins` is `{}`.
- **Proof.** `plugins` is the evidence for which binary ran and for the binary not running.

## Gotchas

- `BIN` and the bundled binary are different store paths. The path from `.#goda-wakachi` ends in `goda-wakachi-0.1.0/bin/goda-wakachi`, without `vimplugin-`. Compare the whole path.
- The message `goda-wakachi: no binary found` appears only when no binary exists in the plugin directory. The flake app always bundles one, so this harness cannot reach that message. It is unverified here.
- A path in `g:goda_wakachi#binary` that is not executable is skipped without an error, and the bundled binary starts.
- The first motion loads the dictionary and takes longer than the later ones. `drive.sh` waits up to 120 seconds, which also covers a rebuild.
