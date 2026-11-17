# Motions

In Normal mode, `w` and `b` move the cursor to the start of the next or previous bunsetsu, and `e` and `ge` move it to the end of the next or previous bunsetsu. The motions take a count and cross lines.

## Sub-features

- `motion-w` moves forward to the start of a bunsetsu.
- `motion-b` moves backward to the start of a bunsetsu.
- `motion-e` moves forward to the last character of a bunsetsu.
- `motion-ge` moves backward to the last character of a bunsetsu.
- `motion-count` repeats a motion.
- `motion-empty-line` stops `w`, `b` and `ge` on an empty line and lets `e` skip it.
- `motion-buffer-end` stops `w` on the last character of the buffer.

## How to get to it (user POV)

- Press `w`, `b`, `e` or `ge` in Normal mode, with the cursor on a line that has Japanese text.
- Type a count first, as in `2w`.

## Driving it with drive.sh

Preconditions:

- The baseline preconditions of the README hold.
- The buffer is `私は学校に行きました。`, an empty line, and `今日は、晴れです。`, passed as `-- '私は学校に行きました。' '' '今日は、晴れです。'`. The recipes write `BUF` for these three arguments.

- **motion-w.** Press `w` at the start. Run `drive.sh <editor> motions --name w --keys w -- BUF`. `after.cursor` is `[1, 7]`.
- **motion-count.** Press `2w` at the start. Run `drive.sh <editor> motions --name 2w --keys 2w -- BUF`. `after.cursor` is `[1, 16]`.
- **motion-b.** Press `b` inside the second bunsetsu. Run `drive.sh <editor> motions --name b --keys b --cursor 1,10 -- BUF`. `after.cursor` is `[1, 7]`.
- **motion-e.** Press `e` at the start. Run `drive.sh <editor> motions --name e --keys e -- BUF`. `after.cursor` is `[1, 4]`.
- **motion-ge.** Press `ge` at the start of the third bunsetsu. Run `drive.sh <editor> motions --name ge --keys ge --cursor 1,16 -- BUF`. `after.cursor` is `[1, 13]`.
- **motion-empty-line, w.** Press `w` in the last bunsetsu of line 1. Run `drive.sh <editor> motions --name w-empty --keys w --cursor 1,16 -- BUF`. `after.cursor` is `[2, 1]`.
- **motion-empty-line, b.** Press `b` at the start of line 3. Run `drive.sh <editor> motions --name b-empty --keys b --cursor 3,1 -- BUF`. `after.cursor` is `[2, 1]`.
- **motion-empty-line, e.** Press `e` on the last character of line 1. Run `drive.sh <editor> motions --name e-skips-empty --keys e --cursor 1,31 -- BUF`. `after.cursor` is `[3, 10]`.
- **motion-empty-line, ge.** Press `ge` at the start of line 3. Run `drive.sh <editor> motions --name ge-empty --keys ge --cursor 3,1 -- BUF`. `after.cursor` is `[2, 1]`.
- **motion-buffer-end.** Press `w` in the last bunsetsu of the buffer. Run `drive.sh <editor> motions --name w-buffer-end --keys w --cursor 3,13 -- BUF`. `after.cursor` is `[3, 25]`.
- **Proof.** In every file, `after.lines` equals `before.lines` and `plugins` names a `goda-wakachi` binary.

## Gotchas

- Columns are bytes. The second bunsetsu of line 1 starts at column 7, not 3.
- `--cursor` on a byte in the middle of a character puts the cursor on that character.
- An empty line has no Japanese text, but the plugin handles it. A line with only ASCII characters is different, see the startup feature.
