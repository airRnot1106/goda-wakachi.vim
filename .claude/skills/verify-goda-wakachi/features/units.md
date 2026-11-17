# Units and segment()

`g:goda_wakachi#unit` chooses what one motion step covers, a bunsetsu or a morpheme. `goda_wakachi#segment()` returns the segments of a string as byte offsets, so a user can see where the motions stop.

## Sub-features

- `unit-default` moves by bunsetsu when the variable is unset.
- `unit-morpheme` moves by morpheme when the variable is `'morpheme'`.
- `segment-default` returns the bunsetsu of a string.
- `segment-unit` returns the morphemes when the second argument is `'morpheme'`.
- `segment-unknown-unit` throws on a unit that does not exist.

## How to get to it (user POV)

- Set `let g:goda_wakachi#unit = 'morpheme'` in the vimrc or on the command line, then use the motions.
- Run `:echo goda_wakachi#segment('私は学校に行く')`.
- Run `:echo goda_wakachi#segment('私は学校に行く', 'morpheme')`.

## Driving it with drive.sh

Preconditions:

- The baseline preconditions of the README hold.
- `W` stands for `'私は学校に行きました。'`.

- **unit-default.** Press `w` with the variable unset. Run `drive.sh <editor> units --name bunsetsu-w --keys w -- W`. `after.cursor` is `[1, 7]`.
- **unit-morpheme.** Press `w` with the unit set. Run `drive.sh <editor> units --name morpheme-w --keys w --unit morpheme -- W`. `after.cursor` is `[1, 4]`.
- **segment-default.** Evaluate the function. Run `drive.sh <editor> units --name segment --expr "goda_wakachi#segment('私は学校に行く')" -- ''`. `expr.value` is `[[0, 3], [6, 12], [15, 18]]`.
- **segment-unit.** Evaluate it with a unit. Run `drive.sh <editor> units --name segment-morpheme --expr "goda_wakachi#segment('私は学校に行く', 'morpheme')" -- ''`. `expr.value` is `[[0, 0], [3, 3], [6, 9], [12, 12], [15, 18]]`.
- **segment-unknown-unit.** Evaluate it with a unit that does not exist. Run `drive.sh <editor> units --name unknown-unit --expr "goda_wakachi#segment('猫', 'sentence')" -- ''`. `drive.sh` exits with code 2 and `error` contains `unknown unit "sentence"`.
- **Proof.** The pair `bunsetsu-w` and `morpheme-w` shows the same key landing on different columns.

## Gotchas

- The offsets of `segment()` count from 0 and cursor columns count from 1. Segment start 6 is cursor column 7.
- Each pair is `[start, last]`, the first byte of the first and of the last character. A one-character segment has both equal.
- `segment-unknown-unit` is the one case where exit code 2 is the pass.
- The error text differs by editor. Neovim prefixes it with `Invoking 'wakachi.segment' on channel`, Vim with `goda:`. Match on `unknown unit "sentence"`.
