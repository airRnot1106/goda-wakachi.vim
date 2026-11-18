---
name: verify-segment-offsets
description: Check that the byte offsets Segment returns are safe cursor positions for every generated Japanese line, with Go fuzzing of the real code. Use after any change to internal/wakachi/segment.go (the roles table, roleOf, the Segment loop, how Start and Last are computed), after bumping kagome, kagome-dict or Go, and when a motion lands in the middle of a character, on whitespace, or skips text.
---

# Verify the segment offsets

`Segmenter.Segment` in `internal/wakachi/segment.go` returns `[Start, Last]` byte offsets. `autoload/goda_wakachi.vim` turns them into cursor columns without checking them, so a wrong offset moves the cursor to the wrong byte and an operator such as `dw` deletes the wrong text. The unit tests cover ten sentences. This check runs the real function on generated lines and tests four properties on every result.

This is not a proof. No verifier runs on Go code that calls the kagome dictionary, so the check is fuzzing. Go's coverage-guided fuzzer generates the lines, and a pass means that no generated line broke a property.

## The properties

| Fuzz target | Property | Harm when it breaks |
| --- | --- | --- |
| `FuzzSegmentOnCharacters` | Every segment starts and ends on a character of the line. | The cursor lands outside the line or inside a multibyte character. |
| `FuzzSegmentInOrder` | The segments go left to right and do not overlap. | `w` moves backward, or two presses land on the same bunsetsu. |
| `FuzzSegmentWithoutWhitespace` | No segment holds whitespace. | `w` stops on a space, and `dw` deletes a space with the word. |
| `FuzzSegmentCoversText` | Every character that is not whitespace is in a segment. | The motions cannot stop in part of the text. |

The targets and their helper are in `internal/wakachi/segment_fuzz_test.go`. Each target checks both units, `bunsetsu` and `morpheme`.

Every target also fails with `did not return within 5s` when one call of `Segment` takes longer than that. goda.vim gives a request up after 10 seconds, and the editor does not respond meanwhile.

## Coverage record

Sync commit: `4f6af65`

At the sync commit the check describes this code:

- `internal/wakachi/segment.go`: `Segmenter.Segment`, `roleOf`, `posOf` and the `roles` table.
- `go.mod` and `go.sum`: the versions of `github.com/ikawaha/kagome/v2` and `github.com/ikawaha/kagome-dict/ipa`, because the tokens come from them.

Not covered:

- `autoload/goda_wakachi.vim`. Whether the motions use the offsets correctly is the job of the `verify-goda-wakachi` skill and `go test ./e2e`.
- `internal/wakachi/wakachi.go`, which copies the offsets into the answer.
- Whether a bunsetsu boundary is the right one for Japanese grammar. The properties say an offset is safe, not that it is where a reader would split.

## Run it

```sh
nix develop -c .claude/skills/verify-segment-offsets/scripts/check.sh
```

It takes about 10 seconds. Each target runs 100000 generated inputs. Pass a number to change that, as in `check.sh 1000000`.

The output names the Go version, the revision, whether the covered code changed since the sync commit, and `PASS` or `FAIL` per target. The exit code is 0 when every property held.

A `FAIL` prints the failing call in this form:

```
Segment("Vim Vim -\u3000に", "bunsetsu")[2] = {Start:8 Last:12} holds whitespace at byte 9
```

The message says that this line, in this unit, gave a third segment from byte 8 to the character at byte 12, and that the byte at 9 is whitespace. Go prints a full-width space as `\u3000`. The fuzzer shrinks the line before it reports it.

Logs go to `artifacts/verify-segment-offsets/<target>.log` and failing inputs to `artifacts/verify-segment-offsets/counterexamples/<target>/`. Git ignores `artifacts/`. `check.sh` moves the failing input out of `internal/wakachi/testdata/fuzz/`, where Go writes it, because a file there fails every later `go test`.

## Scope and bounds

- Lines are valid UTF-8. The targets skip a line with invalid bytes. One probe without that skip failed `FuzzSegmentOnCharacters` within a second. Nobody has analysed it, and whether Vim or Neovim can send such a line to the binary is unknown.
- The fuzzer feeds two lines per input: a raw string it mutates, and a line composed from the `fragments` list in the test file. The list holds particles, verbs, punctuation, brackets, half-width kana, ASCII, an emoji, and the ASCII space, full-width space and tab.
- A composed line has at most 64 fragments, and a raw line at most 256 bytes. The test cuts longer inputs to that size, so the check does not reach longer lines. Do not remove the cut. Without it the fuzzer grows inputs to megabytes, one line takes minutes to tokenize, and a run does not end.
- A pass covers the inputs generated in that run. It says nothing about a line the fuzzer did not reach.
- Results depend on the dictionary. A new kagome-dict version changes the tokens and needs a new run.

## Open findings

None. `check.sh` prints four `PASS` lines and exits with code 0.

One finding is closed. kagome returns a full-width space and the symbol after it as one token, and `Segment` kept the space inside a segment, so `w` stopped on the space. `Segment` now finds the words inside each token. The seed `Vim\u3000-学校` in the test file and the case `w skips a full-width space before a symbol` in `e2e/e2e_test.go` guard it.

## A real bug or a wrong check

When a target fails, decide which it is before changing anything.

1. Rerun the input alone. Copy the reported file from `artifacts/verify-segment-offsets/counterexamples/<target>/` back to `internal/wakachi/testdata/fuzz/<target>/`, run `nix develop -c go test ./internal/wakachi -run '<target>'`, then remove the copy.
2. Read the line and the segment in the message, and work out by hand what a user would see with the cursor at `Start + 1` and at `Last + 1` (Vim columns count from 1).
3. It is a real bug when the user would see the harm in the table. Report it with the message, and do not edit the property until it passes.
4. It is a wrong check when the property itself no longer matches what the plugin promises, for example after a deliberate decision that a segment may hold whitespace. Then change the property, and say so in the commit.

A compile error in the log, lines like `segment.go:12:3: ...`, is not a property failure. Fix the build first.

## When the covered code changed

`check.sh` prints `covered code: CHANGED since the sync commit` when `segment.go`, `go.mod` or `go.sum` differ from the sync commit.

1. Read the diff it prints. Check that `Segment` still returns byte offsets with the meaning in the `Segment` type comment, and that the four properties still say what the motions need.
2. If the change adds a promise, such as a new field on `Segment` or a new unit, add a fuzz target for it and a mutant for that target in `scripts/mutants.sh`. A new unit also goes in the unit list of `fuzzCursorContract` in the test file.
3. Run `check.sh`, then `scripts/mutants.sh`.
4. Only then replace the sync commit above with the commit that holds the change. Do not move it forward for a change you have not read.

## Show that the check can fail

```sh
nix develop -c .claude/skills/verify-segment-offsets/scripts/mutants.sh
```

It breaks `segment.go` in one way per property, expects that property's target to fail with its own message, and restores the file. It takes about 5 seconds and prints `CAUGHT` four times.

- `STALE` means the line the mutant edits is gone from `segment.go`. Update the `sed` script in `mutants.sh` to break the new code in the same way.
- `MISSED` means the property did not notice the break. The property or the generated lines are too weak. Fix them, not the mutant.

Run it after any edit to `segment_fuzz_test.go` or to the `Segment` loop. It restores `segment.go` from a copy it takes at the start, so uncommitted changes in that file survive.

## Helpers

- `scripts/check.sh [execs]` runs the four targets.
- `scripts/mutants.sh` runs the four broken variants.
- Both need the dev shell and refuse to run outside it, so the Go version is the one in `flake.lock`.
- `nix develop -c go test ./internal/wakachi` also runs the seeds of every target as ordinary tests, in under a second. CI does that through the `unit` check. It does not fuzz.
