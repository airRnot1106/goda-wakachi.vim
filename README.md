# goda-wakachi.vim

Move by bunsetsu (文節) in Japanese text with `w`, `b`, `e` and `ge`, in Vim and Neovim.

Japanese has no spaces between words, so the native `w` jumps over a whole run of kanji or kana. goda-wakachi.vim splits each line with [kagome](https://github.com/ikawaha/kagome), a morphological analyzer written in Go, and stops at every bunsetsu: `私は`, `学校に`, `行きました。`. It runs on [goda.vim](https://github.com/Shougo/goda.vim).

## Features

- Works in Vim and Neovim
- `w`, `b`, `e` and `ge` in Normal, Visual and Operator-pending mode, with counts
- The binary embeds the IPA dictionary, so there is no MeCab to install and no dictionary to download
- A line of only ASCII keeps the native motions
- Moves by morpheme instead of bunsetsu with one option

## Requirements

- Vim 9.1 with `+job` and `+channel`, or Neovim 0.11
- [goda.vim](https://github.com/Shougo/goda.vim)
- [Nix](https://nixos.org) with flakes enabled, or [Go](https://go.dev) 1.26, to build the binary

Windows is not supported.

## Try it

With Nix, this opens an editor that loads only goda.vim and this plugin, with the motions on `w`, `b`, `e` and `ge`:

```sh
nix run github:airRnot1106/goda-wakachi.vim -- file.txt       # Neovim
nix run github:airRnot1106/goda-wakachi.vim#vim -- file.txt   # Vim
```

Inside a clone, `nix run . -- file.txt` does the same.

## Installation

### Using a plugin manager

Install goda.vim and goda-wakachi.vim, then run `nix build` inside the plugin directory. The plugin expects the binary at `result/bin/goda-wakachi`.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'airRnot1106/goda-wakachi.vim',
  dependencies = { 'Shougo/goda.vim' },
  build = 'nix build',
}
```

### Without Nix

Build the binary with Go instead. Run this inside the plugin directory:

```sh
go build -o bin/goda-wakachi .
```

The plugin finds the binary at `bin/goda-wakachi`.

## Usage

The plugin defines no key mappings. Map the keys you want:

```vim
nmap w <Plug>(goda-wakachi-w)
nmap b <Plug>(goda-wakachi-b)
nmap e <Plug>(goda-wakachi-e)
nmap ge <Plug>(goda-wakachi-ge)
xmap w <Plug>(goda-wakachi-w)
xmap b <Plug>(goda-wakachi-b)
xmap e <Plug>(goda-wakachi-e)
xmap ge <Plug>(goda-wakachi-ge)
omap w <Plug>(goda-wakachi-w)
omap b <Plug>(goda-wakachi-b)
omap e <Plug>(goda-wakachi-e)
omap ge <Plug>(goda-wakachi-ge)
```

On `私は学校に行きました。`, `w` moves from `私` to `学` and then to `行`, and `dw` on `学` deletes `学校に`. The first motion starts the binary and loads the dictionary.

On a line that has only ASCII characters, the mappings run the native motions. `w`, `b` and `ge` stop on an empty line, and `e` skips it. `dw` on the last bunsetsu of a line deletes to the end of the line and keeps the next line.

See `:help goda-wakachi`.

## Options

| Variable | Default | Description |
| --- | --- | --- |
| `g:goda_wakachi#binary` | Unset | Path to the binary. Overrides `bin/goda-wakachi` and `result/bin/goda-wakachi`. |
| `g:goda_wakachi#unit` | `'bunsetsu'` | What one motion step covers: `'bunsetsu'` or `'morpheme'`. |

| Unit | `私は学校に行きました。` |
| --- | --- |
| `'bunsetsu'` | `私は` `学校に` `行きました。` |
| `'morpheme'` | `私` `は` `学校` `に` `行き` `まし` `た` `。` |

If something fails, check `goda#log('wakachi')`.

## Functions

`goda_wakachi#segment({text} [, {unit}])` splits `{text}` and returns a list of `[start, last]` pairs. `start` is the byte offset of the first character of a segment and `last` is the byte offset of its last character. Both count from 0. Whitespace belongs to no segment.

```vim
:echo goda_wakachi#segment('私は学校に行く')
[[0, 3], [6, 12], [15, 18]]
```

## Limits

The plugin builds a bunsetsu from the part of speech of each token. It does not parse the sentence, so some results differ from a grammar book:

- Nouns next to each other always make one bunsetsu. `今日学校に` stays together, although `今日` and `学校に` are two bunsetsu.
- A dependent noun joins the word before it. `食べたい物を` is one bunsetsu.
- The dictionary decides the tokens. A word that it does not know may split in the wrong place.
- `cw` changes the same text as `dw` deletes, the space after the bunsetsu included. The native `cw` stops before the space.

## Development

```sh
nix develop
go test ./...
nix flake check
```

`go test ./e2e` runs the motions in the `vim` and `nvim` of `PATH`, and skips an editor that is missing.

## Special thanks

- [goda.vim](https://github.com/Shougo/goda.vim)
- [kagome](https://github.com/ikawaha/kagome)

## License

MIT.

The binary embeds the IPA dictionary of [kagome-dict](https://github.com/ikawaha/kagome-dict). The Go code of kagome-dict is under the MIT License. The dictionary data is mecab-ipadic-2.7.0-20070801, which NAIST distributes under its own notice together with the conditions of ICOT Free Software. The `NOTICE.txt` of the `github.com/ikawaha/kagome-dict/ipa` module has the full text.
