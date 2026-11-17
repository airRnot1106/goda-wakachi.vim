// Package wakachi is the goda-wakachi plugin. It splits lines into bunsetsu
// for autoload/goda_wakachi.vim.
package wakachi

import (
	"context"

	"github.com/Shougo/goda.vim/sdk"
)

// scriptVersion matches the version autoload/goda_wakachi.vim passes to goda#register.
const scriptVersion = 1

// Wakachi answers with the segments of its Segmenter.
type Wakachi struct {
	segmenter Segmenter
}

// New returns a plugin that loads the dictionary on the first request.
func New() *Wakachi {
	return &Wakachi{}
}

// Name implements sdk.Plugin.
func (w *Wakachi) Name() string { return "wakachi" }

// ScriptVersion implements sdk.ScriptVersioner.
func (w *Wakachi) ScriptVersion() int { return scriptVersion }

// Handlers implements sdk.Plugin.
func (w *Wakachi) Handlers() map[string]sdk.Handler {
	return map[string]sdk.Handler{
		"segment": w.segment,
	}
}

// segment takes (text [, unit]) and returns a list of [start, last] pairs.
func (w *Wakachi) segment(_ context.Context, _ sdk.Host, params []any) (any, error) {
	var text string
	unit := string(Bunsetsu)
	if err := sdk.DecodeArgs(params, &text, sdk.Optional(&unit)); err != nil {
		return nil, err
	}
	segments, err := w.segmenter.Segment(text, Unit(unit))
	if err != nil {
		return nil, err
	}
	pairs := make([]any, len(segments))
	for i, s := range segments {
		pairs[i] = []any{int64(s.Start), int64(s.Last)}
	}
	return pairs, nil
}
