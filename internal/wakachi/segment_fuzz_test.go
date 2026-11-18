package wakachi

import (
	"strings"
	"testing"
	"time"
	"unicode"
	"unicode/utf8"
)

var fragments = []string{
	"私", "は", "学校", "に", "行き", "まし", "た", "。", "、", "今日",
	"勉強", "する", "食べ", "たい", "物", "を", "お", "茶", "「", "」",
	"の", "こと", "美しい", "とても", "ない", "で", "が", "から", "走っ", "て",
	"いる", "東京", "都", "ｶﾀｶﾅ", "Vim", "foo", "123", "-", "(", ")",
	"…", "é", "😀", " ", "　", "\t",
}

var fuzzSegmenter Segmenter

// limit is how long one call of Segment may take. goda.vim gives a request
// up after 10 seconds, and the editor does not respond meanwhile.
const limit = 5 * time.Second

const (
	maxLineFragments = 64
	maxLineBytes     = 256
)

func compose(picks []byte) string {
	if len(picks) > maxLineFragments {
		picks = picks[:maxLineFragments]
	}
	var text strings.Builder
	for _, pick := range picks {
		text.WriteString(fragments[int(pick)%len(fragments)])
	}
	return text.String()
}

func clip(raw string) string {
	if len(raw) <= maxLineBytes {
		return raw
	}
	cut := maxLineBytes
	for cut > 0 && !utf8.RuneStart(raw[cut]) {
		cut--
	}
	return raw[:cut]
}

func validUTF8Lines(raw string, picks []byte) []string {
	lines := []string{}
	for _, text := range []string{clip(raw), compose(picks)} {
		if utf8.ValidString(text) {
			lines = append(lines, text)
		}
	}
	return lines
}

func segmentWithinLimit(t *testing.T, text string, unit Unit) []Segment {
	t.Helper()
	type answer struct {
		segments []Segment
		err      error
	}
	done := make(chan answer, 1)
	go func() {
		segments, err := fuzzSegmenter.Segment(text, unit)
		done <- answer{segments, err}
	}()
	select {
	case got := <-done:
		if got.err != nil {
			t.Fatalf("Segment(%q, %q): %v", text, unit, got.err)
		}
		return got.segments
	case <-time.After(limit):
		t.Fatalf("Segment(%q, %q) did not return within %s", text, unit, limit)
		return nil
	}
}

type cursorContract func(t *testing.T, text string, unit Unit, segments []Segment)

func fuzzCursorContract(f *testing.F, holds cursorContract) {
	f.Add("私は学校に行きました。", []byte{0, 1, 2, 3, 4, 5, 6, 7})
	f.Add("今日は、晴れです。", []byte{9, 1, 8, 43, 10, 11})
	f.Add("「猫」と言った", []byte{18, 14, 19, 20, 21})
	f.Add("Vim で 編集する", []byte{34, 43, 25, 44, 10, 11, 45})
	f.Add("", []byte{})
	f.Fuzz(func(t *testing.T, raw string, picks []byte) {
		for _, text := range validUTF8Lines(raw, picks) {
			for _, unit := range []Unit{Bunsetsu, Morpheme} {
				holds(t, text, unit, segmentWithinLimit(t, text, unit))
			}
		}
	})
}

func byteAfterLastCharacter(text string, segment Segment) int {
	_, size := utf8.DecodeRuneInString(text[segment.Last:])
	return segment.Last + size
}

func inLine(text string, segment Segment) bool {
	return 0 <= segment.Start && segment.Start <= segment.Last && segment.Last < len(text)
}

func FuzzSegmentOnCharacters(f *testing.F) {
	fuzzCursorContract(f, func(t *testing.T, text string, unit Unit, segments []Segment) {
		for i, segment := range segments {
			if !inLine(text, segment) {
				t.Fatalf("Segment(%q, %q)[%d] = %+v is outside the line of %d bytes", text, unit, i, segment, len(text))
			}
			if !utf8.RuneStart(text[segment.Start]) || !utf8.RuneStart(text[segment.Last]) {
				t.Fatalf("Segment(%q, %q)[%d] = %+v is in the middle of a character", text, unit, i, segment)
			}
		}
	})
}

func FuzzSegmentInOrder(f *testing.F) {
	fuzzCursorContract(f, func(t *testing.T, text string, unit Unit, segments []Segment) {
		after := 0
		for i, segment := range segments {
			if !inLine(text, segment) {
				t.Skip("FuzzSegmentOnCharacters reports this")
			}
			if segment.Start < after {
				t.Fatalf("Segment(%q, %q)[%d] = %+v starts before byte %d, where the segment before it ends", text, unit, i, segment, after)
			}
			after = byteAfterLastCharacter(text, segment)
		}
	})
}

func FuzzSegmentWithoutWhitespace(f *testing.F) {
	fuzzCursorContract(f, func(t *testing.T, text string, unit Unit, segments []Segment) {
		for i, segment := range segments {
			if !inLine(text, segment) {
				t.Skip("FuzzSegmentOnCharacters reports this")
			}
			for at, r := range text[segment.Start:byteAfterLastCharacter(text, segment)] {
				if unicode.IsSpace(r) {
					t.Fatalf("Segment(%q, %q)[%d] = %+v holds whitespace at byte %d", text, unit, i, segment, segment.Start+at)
				}
			}
		}
	})
}

func FuzzSegmentCoversText(f *testing.F) {
	fuzzCursorContract(f, func(t *testing.T, text string, unit Unit, segments []Segment) {
		covered := make([]bool, len(text))
		for _, segment := range segments {
			if !inLine(text, segment) {
				t.Skip("FuzzSegmentOnCharacters reports this")
			}
			for at := segment.Start; at < byteAfterLastCharacter(text, segment); at++ {
				covered[at] = true
			}
		}
		for at, r := range text {
			if !unicode.IsSpace(r) && !covered[at] {
				t.Fatalf("Segment(%q, %q) = %+v leaves the character at byte %d in no segment", text, unit, segments, at)
			}
		}
	})
}
