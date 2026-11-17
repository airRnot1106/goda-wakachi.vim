# Operators and Visual mode

After an operator, the motions select text by bunsetsu. `w` and `b` are exclusive, `e` and `ge` are inclusive. `dw` on the last bunsetsu of a line stops at the end of the line. In Visual mode the motions extend the selection.

## Sub-features

- `op-dw` deletes from the cursor to the start of the next bunsetsu.
- `op-de` deletes through the last character of the bunsetsu.
- `op-dge` deletes back through the last character of the bunsetsu before.
- `op-dw-line-end` deletes the last bunsetsu of a line and keeps the next line.
- `op-dw-buffer-end` deletes the last bunsetsu of the buffer whole.
- `op-space` makes `dw` delete the space after a bunsetsu and `de` keep it.
- `op-cw` changes the text that `dw` deletes, the space included.
- `visual-w` and `visual-e` extend a Visual selection.

## How to get to it (user POV)

- Type an operator and then a motion, as in `dw`, `de`, `dge`, `cw` or `yw`.
- Press `v`, then a motion.

## Driving it with drive.sh

Preconditions:

- The baseline preconditions of the README hold.
- `W` stands for `'私は学校に行きました。'` and `S` for `'今日は、晴れです。'`.

- **op-dw.** Type `dw` on the second bunsetsu. Run `drive.sh <editor> operators --name dw --keys dw --cursor 1,7 -- W`. `after.lines` is `["私は行きました。"]` and `after.yank` is `学校に`.
- **op-de.** Type `de` on the second bunsetsu. Run `drive.sh <editor> operators --name de --keys de --cursor 1,7 -- W`. `after.lines` is `["私は行きました。"]` and `after.yank` is `学校に`.
- **op-dge.** Type `dge` on the third bunsetsu. Run `drive.sh <editor> operators --name dge --keys dge --cursor 1,16 -- W`. `after.lines` is `["私は学校きました。"]`.
- **op-dw-line-end.** Type `dw` on the last bunsetsu of line 1. Run `drive.sh <editor> operators --name dw-last --keys dw --cursor 1,16 -- W S`. `after.lines` is `["私は学校に", "今日は、晴れです。"]` and `after.yank` is `行きました。`.
- **op-dw-buffer-end.** Type `dw` on the last bunsetsu of a one-line buffer. Run `drive.sh <editor> operators --name dw-buffer-end --keys dw --cursor 1,16 -- W`. `after.lines` is `["私は学校に"]`.
- **op-space, dw.** Type `dw` on a bunsetsu followed by a space. Run `drive.sh <editor> operators --name dw-space --keys dw -- 'Vim で 編集する'`. `after.lines` is `["で 編集する"]`.
- **op-space, de.** Type `de` in the same place. Run `drive.sh <editor> operators --name de-space --keys de -- 'Vim で 編集する'`. `after.lines` is `[" で 編集する"]`.
- **op-cw.** Type `cwX` and leave Insert mode. Run `drive.sh <editor> operators --name cw --keys 'cwX\<Esc>' -- 'Vim で 編集する'`. `after.lines` is `["Xで 編集する"]` and `after.yank` is `Vim `, with the space.
- **visual-w.** Select with `vw` and yank. Run `drive.sh <editor> operators --name visual-w --keys vwy -- W`. `after.yank` is `私は学`.
- **visual-e.** Select with `ve` and yank. Run `drive.sh <editor> operators --name visual-e --keys vey -- W`. `after.yank` is `私は`.
- **Proof.** Each file shows the text before, the keys, the text after and the register.

## Gotchas

- The native `cw` keeps the space after a word. This plugin's `cw` removes it. The README lists this as a known difference, so `Xで 編集する` is the expected result, not a failure.
- `visual-w` yanks one character of the next bunsetsu, because Visual mode includes the character under the cursor.
- A key sequence that ends in Insert mode leaves `after.mode` as `i`. End it with `\<Esc>` when the next check needs Normal mode.
- Vim reports Operator-pending mode differently in Ex mode. `drive.sh` starts Vim with `--not-a-term` for this reason. Do not add `-es`.
