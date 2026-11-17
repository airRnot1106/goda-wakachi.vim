package wakachi

import (
	"reflect"
	"testing"
	"unicode/utf8"
)

func surfaces(t *testing.T, text string, unit Unit) []string {
	t.Helper()
	var s Segmenter
	segments, err := s.Segment(text, unit)
	if err != nil {
		t.Fatal(err)
	}
	got := []string{}
	for _, segment := range segments {
		_, size := utf8.DecodeRuneInString(text[segment.Last:])
		got = append(got, text[segment.Start:segment.Last+size])
	}
	return got
}

func TestSegment(t *testing.T) {
	tests := []struct {
		name string
		text string
		unit Unit
		want []string
	}{
		{"particles and auxiliary verbs join the bunsetsu before them", "私は学校に行きました", Bunsetsu, []string{"私は", "学校に", "行きました"}},
		{"a dependent verb joins the bunsetsu before it", "本を読んでいる", Bunsetsu, []string{"本を", "読んでいる"}},
		{"punctuation joins the bunsetsu before it", "今日は、晴れです。", Bunsetsu, []string{"今日は、", "晴れです。"}},
		{"brackets join the bunsetsu inside them", "「猫」と言った", Bunsetsu, []string{"「猫」と", "言った"}},
		{"a prefix joins the word after it", "お茶を飲む", Bunsetsu, []string{"お茶を", "飲む"}},
		{"a compound noun is one bunsetsu", "東京大学に行く", Bunsetsu, []string{"東京大学に", "行く"}},
		{"する joins the noun before it", "日本語を勉強する", Bunsetsu, []string{"日本語を", "勉強する"}},
		{"whitespace belongs to no bunsetsu", "Vim で 編集する", Bunsetsu, []string{"Vim", "で", "編集する"}},
		{"an empty line has no bunsetsu", "", Bunsetsu, []string{}},
		{"a morpheme is one word", "私は学校に行く", Morpheme, []string{"私", "は", "学校", "に", "行く"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := surfaces(t, tt.text, tt.unit); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("Segment(%q) = %q, want %q", tt.text, got, tt.want)
			}
		})
	}
}

func TestSegmentReturnsByteOffsets(t *testing.T) {
	var s Segmenter
	got, err := s.Segment("私は 行く", Bunsetsu)
	if err != nil {
		t.Fatal(err)
	}
	want := []Segment{{Start: 0, Last: 3}, {Start: 7, Last: 10}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %v, want %v", got, want)
	}
}

func TestSegmentRejectsUnknownUnit(t *testing.T) {
	var s Segmenter
	if _, err := s.Segment("猫", Unit("sentence")); err == nil {
		t.Error("want an error for an unknown unit")
	}
}
