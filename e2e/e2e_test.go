// Package e2e runs the plugin in real editors.
package e2e

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

// Vim runs without -es, because mode() does not report Operator-pending mode
// in Ex mode.
var editors = []struct {
	name    string
	command []string
}{
	{"vim", []string{"vim", "-u", "NONE", "-N", "-n", "-i", "NONE", "--not-a-term", "-S"}},
	{"nvim", []string{"nvim", "-u", "NONE", "-n", "-i", "NONE", "--headless", "-S"}},
}

const (
	went  = "私は学校に行きました。"
	sunny = "今日は、晴れです。"
	ascii = "hello world foo"
)

var (
	prose  = []string{went, "", sunny}
	spaced = []string{"Vim で 編集する"}
	mixed  = []string{ascii, went}
)

// A motionCase types Keys with the cursor at Cursor, a line and a byte column
// that both count from 1. WantLines is Lines when the keys change no text.
type motionCase struct {
	Name       string   `json:"name"`
	Lines      []string `json:"lines"`
	Cursor     [2]int   `json:"cursor"`
	Keys       string   `json:"keys"`
	Unit       string   `json:"unit"`
	WantCursor [2]int   `json:"-"`
	WantLines  []string `json:"-"`
	WantYank   string   `json:"-"`
}

var motionCases = []motionCase{
	{Name: "w moves to the next bunsetsu", Lines: prose, Cursor: [2]int{1, 1}, Keys: "w", WantCursor: [2]int{1, 7}},
	{Name: "w takes a count", Lines: prose, Cursor: [2]int{1, 1}, Keys: "2w", WantCursor: [2]int{1, 16}},
	{Name: "w stops on an empty line", Lines: prose, Cursor: [2]int{1, 16}, Keys: "w", WantCursor: [2]int{2, 1}},
	{Name: "w leaves an empty line", Lines: prose, Cursor: [2]int{2, 1}, Keys: "w", WantCursor: [2]int{3, 1}},
	{Name: "w stops at the end of the buffer", Lines: prose, Cursor: [2]int{3, 13}, Keys: "w", WantCursor: [2]int{3, 25}},
	{Name: "b moves to the start of the bunsetsu", Lines: prose, Cursor: [2]int{1, 10}, Keys: "b", WantCursor: [2]int{1, 7}},
	{Name: "b moves to the bunsetsu before", Lines: prose, Cursor: [2]int{1, 16}, Keys: "b", WantCursor: [2]int{1, 7}},
	{Name: "b stops on an empty line", Lines: prose, Cursor: [2]int{3, 1}, Keys: "b", WantCursor: [2]int{2, 1}},
	{Name: "b leaves an empty line", Lines: prose, Cursor: [2]int{2, 1}, Keys: "b", WantCursor: [2]int{1, 16}},
	{Name: "e moves to the end of the bunsetsu", Lines: prose, Cursor: [2]int{1, 1}, Keys: "e", WantCursor: [2]int{1, 4}},
	{Name: "e skips an empty line", Lines: prose, Cursor: [2]int{1, 31}, Keys: "e", WantCursor: [2]int{3, 10}},
	{Name: "ge moves to the end of the bunsetsu before", Lines: prose, Cursor: [2]int{1, 16}, Keys: "ge", WantCursor: [2]int{1, 13}},
	{Name: "ge stops on an empty line", Lines: prose, Cursor: [2]int{3, 1}, Keys: "ge", WantCursor: [2]int{2, 1}},
	{Name: "ge leaves an empty line", Lines: prose, Cursor: [2]int{2, 1}, Keys: "ge", WantCursor: [2]int{1, 31}},

	{Name: "dw deletes a bunsetsu", Lines: prose, Cursor: [2]int{1, 7}, Keys: "dw", WantCursor: [2]int{1, 7}, WantLines: []string{"私は行きました。", "", sunny}},
	{Name: "de deletes a bunsetsu", Lines: prose, Cursor: [2]int{1, 7}, Keys: "de", WantCursor: [2]int{1, 7}, WantLines: []string{"私は行きました。", "", sunny}},
	{Name: "dw deletes the space after a bunsetsu", Lines: spaced, Cursor: [2]int{1, 1}, Keys: "dw", WantCursor: [2]int{1, 1}, WantLines: []string{"で 編集する"}},
	{Name: "de keeps the space after a bunsetsu", Lines: spaced, Cursor: [2]int{1, 1}, Keys: "de", WantCursor: [2]int{1, 1}, WantLines: []string{" で 編集する"}},
	{Name: "dge deletes back to the end of the bunsetsu before", Lines: prose, Cursor: [2]int{1, 16}, Keys: "dge", WantCursor: [2]int{1, 13}, WantLines: []string{"私は学校きました。", "", sunny}},
	{Name: "dw on the last bunsetsu of a line keeps the next line", Lines: []string{went, sunny}, Cursor: [2]int{1, 16}, Keys: "dw", WantCursor: [2]int{1, 13}, WantLines: []string{"私は学校に", sunny}},
	{Name: "dw on the only bunsetsu of a line keeps the line", Lines: []string{"猫。", sunny}, Cursor: [2]int{1, 1}, Keys: "dw", WantCursor: [2]int{1, 1}, WantLines: []string{"", sunny}},
	{Name: "dw on the last bunsetsu of the buffer deletes it", Lines: []string{went}, Cursor: [2]int{1, 16}, Keys: "dw", WantCursor: [2]int{1, 13}, WantLines: []string{"私は学校に"}},

	{Name: "visual w extends to the next bunsetsu", Lines: prose, Cursor: [2]int{1, 1}, Keys: "vwy", WantCursor: [2]int{1, 1}, WantYank: "私は学"},
	{Name: "visual e extends to the end of the bunsetsu", Lines: prose, Cursor: [2]int{1, 1}, Keys: "vey", WantCursor: [2]int{1, 1}, WantYank: "私は"},

	{Name: "w on an ASCII line is the native motion", Lines: mixed, Cursor: [2]int{1, 1}, Keys: "w", WantCursor: [2]int{1, 7}},
	{Name: "w on an ASCII line takes a count", Lines: mixed, Cursor: [2]int{1, 1}, Keys: "2w", WantCursor: [2]int{1, 13}},
	{Name: "w leaves an ASCII line", Lines: mixed, Cursor: [2]int{1, 13}, Keys: "w", WantCursor: [2]int{2, 1}},
	{Name: "dw on an ASCII line deletes a word", Lines: mixed, Cursor: [2]int{1, 1}, Keys: "dw", WantCursor: [2]int{1, 1}, WantLines: []string{"world foo", went}},
	{Name: "de on an ASCII line keeps the space", Lines: mixed, Cursor: [2]int{1, 1}, Keys: "de", WantCursor: [2]int{1, 1}, WantLines: []string{" world foo", went}},

	{Name: "w moves by morpheme", Lines: prose, Cursor: [2]int{1, 1}, Keys: "w", Unit: "morpheme", WantCursor: [2]int{1, 4}},
	{Name: "e moves by morpheme", Lines: prose, Cursor: [2]int{1, 4}, Keys: "e", Unit: "morpheme", WantCursor: [2]int{1, 10}},
}

type result struct {
	Error string `json:"error"`
	Cases map[string]struct {
		Cursor [2]int   `json:"cursor"`
		Lines  []string `json:"lines"`
		Yank   string   `json:"yank"`
	} `json:"cases"`
	Segments    [][2]int `json:"segments"`
	Morphemes   [][2]int `json:"morphemes"`
	UnknownUnit string   `json:"unknown_unit"`
}

func goda(t *testing.T, root string) string {
	t.Helper()
	if dir := os.Getenv("GODA_WAKACHI_E2E_GODA"); dir != "" {
		return dir
	}
	list := exec.Command("go", "list", "-m", "-f", "{{.Dir}}", "github.com/Shougo/goda.vim")
	list.Dir = root
	out, err := list.Output()
	if err != nil {
		t.Fatal(err)
	}
	return strings.TrimSpace(string(out))
}

// install returns a copy of the plugin with its binary at bin/goda-wakachi,
// where the plugin looks when g:goda_wakachi#binary is unset.
func install(t *testing.T, root string) string {
	t.Helper()
	dir := t.TempDir()
	for _, name := range []string{"autoload", "plugin"} {
		if err := os.CopyFS(filepath.Join(dir, name), os.DirFS(filepath.Join(root, name))); err != nil {
			t.Fatal(err)
		}
	}
	build := exec.Command("go", "build", "-o", filepath.Join(dir, "bin", "goda-wakachi"), ".")
	build.Dir = root
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}
	return dir
}

func TestEditors(t *testing.T) {
	root, err := filepath.Abs("..")
	if err != nil {
		t.Fatal(err)
	}
	plugin := install(t, root)
	cases := filepath.Join(t.TempDir(), "cases.json")
	for i := range motionCases {
		if motionCases[i].Unit == "" {
			motionCases[i].Unit = "bunsetsu"
		}
	}
	data, err := json.Marshal(motionCases)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(cases, data, 0o644); err != nil {
		t.Fatal(err)
	}
	for _, editor := range editors {
		t.Run(editor.name, func(t *testing.T) {
			if _, err := exec.LookPath(editor.command[0]); err != nil {
				if os.Getenv("GODA_WAKACHI_E2E_STRICT") != "" {
					t.Fatal(err)
				}
				t.Skip(err)
			}
			out := filepath.Join(t.TempDir(), "out.json")
			ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, editor.command[0], append(editor.command[1:], "e2e/testdata/driver.vim")...)
			cmd.Dir = root
			cmd.Env = append(os.Environ(),
				"GODA_WAKACHI_E2E_PLUGIN="+plugin,
				"GODA_WAKACHI_E2E_GODA="+goda(t, root),
				"GODA_WAKACHI_E2E_CASES="+cases,
				"GODA_WAKACHI_E2E_OUT="+out,
			)
			if output, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("%v\n%s", err, output)
			}
			data, err := os.ReadFile(out)
			if err != nil {
				t.Fatal(err)
			}
			var got result
			if err := json.Unmarshal(data, &got); err != nil {
				t.Fatal(err)
			}
			check(t, got)
		})
	}
}

func check(t *testing.T, got result) {
	t.Helper()
	if got.Error != "" {
		t.Fatal(got.Error)
	}
	for _, c := range motionCases {
		saw, ok := got.Cases[c.Name]
		if !ok {
			t.Errorf("%s: did not run", c.Name)
			continue
		}
		if saw.Cursor != c.WantCursor {
			t.Errorf("%s: cursor at %v, want %v", c.Name, saw.Cursor, c.WantCursor)
		}
		wantLines := c.WantLines
		if wantLines == nil {
			wantLines = c.Lines
		}
		if !reflect.DeepEqual(saw.Lines, wantLines) {
			t.Errorf("%s: lines %q, want %q", c.Name, saw.Lines, wantLines)
		}
		if c.WantYank != "" && saw.Yank != c.WantYank {
			t.Errorf("%s: yanked %q, want %q", c.Name, saw.Yank, c.WantYank)
		}
	}
	if want := [][2]int{{0, 3}, {6, 12}, {15, 18}}; !reflect.DeepEqual(got.Segments, want) {
		t.Errorf("goda_wakachi#segment(): %v, want %v", got.Segments, want)
	}
	if want := [][2]int{{0, 0}, {3, 3}, {6, 9}, {12, 12}, {15, 18}}; !reflect.DeepEqual(got.Morphemes, want) {
		t.Errorf("goda_wakachi#segment() by morpheme: %v, want %v", got.Morphemes, want)
	}
	if got.UnknownUnit == "" {
		t.Error("goda_wakachi#segment() took an unknown unit")
	}
}
