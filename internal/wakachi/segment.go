package wakachi

import (
	"fmt"
	"strings"
	"sync"
	"unicode/utf8"

	"github.com/ikawaha/kagome-dict/ipa"
	"github.com/ikawaha/kagome/v2/tokenizer"
)

// Unit is what one motion step covers.
type Unit string

const (
	// Bunsetsu is a phrase: a content word with the particles after it.
	Bunsetsu Unit = "bunsetsu"
	// Morpheme is one token of the dictionary.
	Morpheme Unit = "morpheme"
)

// Segment is one unit of a line. Start and Last are the 0-based byte offsets
// of the first byte of its first and of its last character.
type Segment struct {
	Start int
	Last  int
}

// role is the place a token takes in a bunsetsu.
type role int

const (
	// head starts a bunsetsu.
	head role = iota
	// tail joins the bunsetsu before it.
	tail
	// prefix starts a bunsetsu, and the token after it joins.
	prefix
)

// pos is the first two levels of a part of speech in the IPA dictionary.
type pos struct {
	major, minor string
}

const anyMinor = "*"

// roles holds the parts of speech that are not a head.
var roles = map[pos]role{
	{"助詞", anyMinor}:  tail,
	{"助動詞", anyMinor}: tail,
	{"接頭詞", anyMinor}: prefix,
	{"記号", "句点"}:      tail,
	{"記号", "読点"}:      tail,
	{"記号", "括弧閉"}:     tail,
	{"記号", "括弧開"}:     prefix,
	{"名詞", "非自立"}:     tail,
	{"名詞", "接尾"}:      tail,
	{"動詞", "非自立"}:     tail,
	{"動詞", "接尾"}:      tail,
	{"形容詞", "非自立"}:    tail,
	{"形容詞", "接尾"}:     tail,
}

const (
	noun = "名詞"
	verb = "動詞"
)

func posOf(tok tokenizer.Token) pos {
	p := pos{minor: anyMinor}
	features := tok.POS()
	if len(features) > 0 {
		p.major = features[0]
	}
	if len(features) > 1 {
		p.minor = features[1]
	}
	return p
}

// roleOf returns the role of tok after a token of the part of speech prev in
// the same run of text.
func roleOf(tok tokenizer.Token, prev pos) role {
	p := posOf(tok)
	if prev.major == noun {
		// A compound noun is one bunsetsu.
		if p.major == noun {
			return tail
		}
		// A noun with する is one verb, as in 勉強する.
		if base, ok := tok.BaseForm(); ok && p.major == verb && base == "する" {
			return tail
		}
	}
	if r, ok := roles[p]; ok {
		return r
	}
	if r, ok := roles[pos{p.major, anyMinor}]; ok {
		return r
	}
	return head
}

// placed is a token with the role it took.
type placed struct {
	pos  pos
	role role
}

// Segmenter splits lines with the IPA dictionary, which it loads on first use.
type Segmenter struct {
	once sync.Once
	tok  *tokenizer.Tokenizer
	err  error
}

func (s *Segmenter) tokenizer() (*tokenizer.Tokenizer, error) {
	s.once.Do(func() {
		s.tok, s.err = tokenizer.New(ipa.Dict(), tokenizer.OmitBosEos())
	})
	return s.tok, s.err
}

// Segment splits text into segments of unit. Whitespace belongs to no segment.
func (s *Segmenter) Segment(text string, unit Unit) ([]Segment, error) {
	if unit != Bunsetsu && unit != Morpheme {
		return nil, fmt.Errorf("wakachi: unknown unit %q", unit)
	}
	t, err := s.tokenizer()
	if err != nil {
		return nil, err
	}

	segments := []Segment{}
	// The token before the current one, or nil at the start of a run of text.
	var prev *placed
	for _, tok := range t.Tokenize(text) {
		if strings.TrimSpace(tok.Surface) == "" {
			prev = nil
			continue
		}
		_, size := utf8.DecodeLastRuneInString(tok.Surface)
		last := tok.Position + len(tok.Surface) - size

		var before pos
		if prev != nil {
			before = prev.pos
		}
		r := roleOf(tok, before)
		if unit == Bunsetsu && prev != nil && (r == tail || prev.role == prefix) {
			segments[len(segments)-1].Last = last
		} else {
			segments = append(segments, Segment{Start: tok.Position, Last: last})
		}
		prev = &placed{posOf(tok), r}
	}
	return segments, nil
}
