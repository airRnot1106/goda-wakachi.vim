---
name: verify-goda-wakachi
description: Drive goda-wakachi.vim in a real Vim and Neovim and capture proof of what the motions did. Use after changing the Go segmentation, the Vim script or the flake, when asked to prove that w, b, e, ge, an operator or g:goda_wakachi#unit works, or when a motion misbehaves and you need to see the cursor and the buffer before and after.
---

# Verify goda-wakachi.vim

goda-wakachi.vim is an editor plugin. A user touches it by typing `w`, `b`, `e` and `ge` in Vim or Neovim, alone, with a count, after an operator, or in Visual mode. This skill types those keys into a real editor and records the cursor, the buffer and the unnamed register before and after.

The secondary surface is the function `goda_wakachi#segment()`. The Go unit tests and `go test ./e2e` are regression tests, not this skill. Run them with `nix develop -c go test ./...`.

All commands run from the repository root. `scripts/` below means `.claude/skills/verify-goda-wakachi/scripts/`.

## Launch

There is no server. Each drive starts its own editor through the flake app, which builds the plugin first:

- `nix run .#nvim` starts Neovim, and `nix run .#vim` starts Vim.
- The app loads only goda.vim and the built plugin, reads no user configuration, and maps the motions to `w`, `b`, `e` and `ge` in Normal, Visual and Operator-pending mode.
- The plugin binary starts on the first motion on a line with a multibyte character. It is a child of the editor and exits with it.

The flake builds from the git working tree. It sees uncommitted changes to tracked files and does not see untracked files. `git add` a new file before driving.

The first build after a source change takes about a minute. The editor is ready when `drive.sh` prints its JSON.

## Doctor

Run this first, and again whenever a drive fails in a way you do not understand:

```sh
.claude/skills/verify-goda-wakachi/scripts/doctor.sh
```

It prints the revision and whether the tree is dirty, lists untracked files the flake cannot see, builds the plugin, asks the binary for its methods without an editor, and prints the version of both editors. The last line is `doctor: OK`. It writes nothing into the repository.

The handshake line must be `{"result":{"wakachi":["segment"]}}`. Anything else means the binary is not the one this repository builds.

## Drive

```sh
.claude/skills/verify-goda-wakachi/scripts/drive.sh <nvim|vim> <feature> --name <name> [options] -- <line>...
```

| Option | Meaning |
| --- | --- |
| `--name <name>` | File name of the evidence. Required. |
| `--keys <keys>` | Keys to type, in the notation of a Vim double-quoted string, so `\<Esc>` works. |
| `--cursor <l,c>` | Start position, line and byte column, both from 1. Default `1,1`. |
| `--unit <unit>` | Sets `g:goda_wakachi#unit`. Unset by default. |
| `--pre <command>` | Ex command to run before the keys. |
| `--expr <expr>` | Vim expression to evaluate after the keys. Its value lands in `expr.value`. |
| `<line>...` | The buffer, one argument per line. Pass `''` for an empty line. |

Example, `dw` on the second bunsetsu:

```sh
.claude/skills/verify-goda-wakachi/scripts/drive.sh nvim operators --name dw --keys dw --cursor 1,7 -- '私は学校に行きました。'
```

It prints one JSON object. The fields to read:

- `before` and `after` each hold `cursor` (`[line, byte column]`), `lines`, `yank` (the unnamed register) and `mode`.
- `plugins` is `goda#plugins()` at the end. It names the binary that answered, and is `{}` when no motion needed the binary.
- `log` is `goda#log()`, what the binary wrote to stderr.
- `error` is present when the editor threw. `drive.sh` then exits with code 2.

Columns are byte offsets. A kanji or kana is 3 bytes, so in `私は学校に行きました。` the bunsetsu start at columns 1, 7 and 16.

Exit codes: 0 for a completed drive, 1 when the editor failed to start or timed out, 2 when the editor reported an error. A case that expects an error, such as an unknown unit, proves itself with exit code 2 and the text in `error`.

`drive.sh` does not judge the result. Compare `after` with the end state the feature file names.

Run every case in both editors. They differ in the RPC transport and in how they report modes, and a pass in one is not a pass in the other.

The feature map in `features/` lists what to drive for each feature. Read `features/README.md` before a run.

## Evidence

`drive.sh` writes each result to `artifacts/verify/<feature>/<name>.<editor>.json`. The directory is ignored by git. A rerun with the same feature, name and editor replaces the file.

A proof of a feature is the set of JSON files for its cases, from both editors, with the revision from `doctor.sh`. Proof standards:

- Type the keys a user types. Do not call `goda_wakachi#move()` to prove a mapping.
- Keep `before` and `after` together. The file already holds both.
- For an operator, check `lines` and `yank`, not the cursor alone.
- Check `plugins` when the claim is about which binary ran, or that none ran.
- Nothing here is mocked. The editor, goda.vim, the binary and the dictionary are the real ones.

## Cleanup

Each drive removes its own temporary directory and its editor exits by itself. A drive that exceeds 120 seconds kills the editor it started, by pid, and exits with code 1. Nothing else is left running, so there is no teardown step.

Never remove `artifacts/verify/` as cleanup. Delete it only when the user asks to discard the evidence.

## Helpers

- `scripts/doctor.sh` takes no arguments.
- `scripts/drive.sh` is described under Drive. Run it with no arguments for its usage.
- `scripts/driver.vim` is the Vim script `drive.sh` sources inside the editor. Do not run it by hand.

## Isolation

Two drives can run at once. Each has its own editor, its own binary process and its own temporary directory. They collide only when they share feature, name and editor, because that is the evidence path.
