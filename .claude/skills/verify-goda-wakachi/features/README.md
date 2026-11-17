# goda-wakachi.vim verification map

This directory is the maintained source for verifying what a user of goda-wakachi.vim can observe. Read this index before driving the editor, then use the matching feature file as the recipe.

## Baseline preconditions

- Run every command from the repository root.
- `.claude/skills/verify-goda-wakachi/scripts/doctor.sh` ends with `doctor: OK`.
- New files are staged with `git add`, because the flake does not see untracked files.

## Driving conventions

- `drive.sh` below means `.claude/skills/verify-goda-wakachi/scripts/drive.sh`.
- Run each recipe line once with `nvim` and once with `vim`. The recipes write `<editor>` where the editor name goes.
- Every drive starts from a fresh editor and a fresh buffer. No recipe depends on another.
- Cursor positions are `[line, byte column]`, both from 1. A kanji or kana is 3 bytes.
- Treat every command as literal. Keep the quoting.
- The fixture sentences are `私は学校に行きました。`, whose bunsetsu start at columns 1, 7 and 16, and `今日は、晴れです。`, whose bunsetsu start at columns 1 and 13.

## Proof and skip reporting

- The evidence is `artifacts/verify/<feature>/<name>.<editor>.json`, with `before` and `after` in one file.
- Report the revision line of `doctor.sh` with the evidence.
- A case passes when `after` matches the end state its recipe line names, in both editors.
- Report an editor that could not run with the command and its output. Do not report the other editor's pass for it.
- Report a mismatch as a failure with the JSON. Do not change the recipe to match the output.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with drive.sh` starts with `Preconditions:` and uses labeled bullets that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, stable handles, required state, commands, and observable proof.

## Features

- [Motions](./motions.md) covers `w`, `b`, `e` and `ge` in Normal mode, counts, line crossing and empty lines.
- [Operators and Visual mode](./operators.md) covers `dw`, `de`, `dge`, `cw`, the end of a line and Visual selection.
- [Units and segment()](./units.md) covers `g:goda_wakachi#unit` and `goda_wakachi#segment()`.
- [Startup and fallback](./startup.md) covers when the binary starts, which binary is used, and lines with only ASCII characters.
