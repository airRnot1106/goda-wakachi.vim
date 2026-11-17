# goda-wakachi.vim

Move by bunsetsu (文節) in Japanese text with `w`, `b`, `e`, and `ge` in Vim and Neovim.

Japanese does not use spaces between words, so Vim's built-in `w` jumps over an entire sequence of kanji or kana. This plugin uses [kagome](https://github.com/ikawaha/kagome), a Go-based morphological analyzer, to break lines into bunsetsu like `私は`, `学校に`, and `行きました。`. It runs on [goda.vim](https://github.com/Shougo/goda.vim).

## Features

- Works in both Vim and Neovim
- Supports `w`, `b`, `e`, and `ge` across Normal, Visual, and Operator-pending modes, including counts
- Embeds the IPA dictionary in the binary, so it needs no MeCab and downloads no dictionary
- Uses the native motions on lines with only ASCII characters
- Moves by morpheme when `g:goda_wakachi#unit` is `'morpheme'`

## Requirements

- Vim 9.1 compiled with `+job` and `+channel`, or Neovim 0.11
- [goda.vim](https://github.com/Shougo/goda.vim)
- [Nix](https://nixos.org) with flakes enabled, or [Go](https://go.dev) 1.26 to build the binary

Windows is not supported.

## Try it

With Nix, you can open an editor that loads only goda.vim and this plugin, with the motions mapped to `w`, `b`, `e`, and `ge`.

Run this for Neovim:

```sh
nix run github:airRnot1106/goda-wakachi.vim -- file.txt
```

Or this for Vim:

```sh
nix run github:airRnot1106/goda-wakachi.vim#vim -- file.txt
```

Inside a local clone of the repository, `nix run . -- file.txt` does the same.

## Installation

### Using a plugin manager

Install goda.vim and goda-wakachi.vim, then run `nix build` in the plugin directory. The plugin looks for the binary at `result/bin/goda-wakachi`.

Example with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'airRnot1106/goda-wakachi.vim',
  dependencies = { 'Shougo/goda.vim' },
  build = 'nix build',
}
```

### Without Nix

Build the binary with Go. Run this inside the plugin directory:

```sh
go build -o bin/goda-wakachi .
```

The plugin finds the binary at `bin/goda-wakachi`.

## Usage

The plugin defines no default mappings. Map the keys you want:

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

In `私は学校に行きました。`, pressing `w` moves from `私` to `学`, and then to `行`. Running `dw` on `学` deletes `学校に`. The binary starts and loads the dictionary on your first motion.

Lines with only ASCII characters use the native motions. `w`, `b`, and `ge` stop on empty lines, while `e` jumps over them. Running `dw` on the last bunsetsu of a line deletes up to the line break and leaves the next line as it is.

See `:help goda-wakachi` for the rest.

## Options

| Variable | Default | Description |
| --- | --- | --- |
| `g:goda_wakachi#binary` | Unset | Path to the binary. Overrides `bin/goda-wakachi` and `result/bin/goda-wakachi`. |
| `g:goda_wakachi#unit` | `'bunsetsu'` | Motion granularity, either `'bunsetsu'` or `'morpheme'`. |

| Unit | `私は学校に行きました。` |
| --- | --- |
| `'bunsetsu'` | `私は` `学校に` `行きました。` |
| `'morpheme'` | `私` `は` `学校` `に` `行き` `まし` `た` `。` |

When a motion fails, read `goda#log('wakachi')`.

## Functions

`goda_wakachi#segment({text} [, {unit}])` splits `{text}` into segments and returns a list of `[start, last]` byte offset pairs, both starting from 0. No segment includes whitespace.

```vim
:echo goda_wakachi#segment('私は学校に行く')
[[0, 3], [6, 12], [15, 18]]
```

## Known issues and edge cases

The plugin groups tokens into bunsetsu by part of speech alone and does not parse the sentence, so some results differ from Japanese grammar.

Consecutive nouns form one bunsetsu. `今日学校に` stays together, although `今日` and `学校に` are separate bunsetsu. A dependent noun joins the word before it, so `食べたい物を` is one bunsetsu. The plugin may split a word that is not in the dictionary in the wrong place.

`cw` changes the range that `dw` deletes, and that range includes the space after the bunsetsu. The native `cw` stops before the space.

## Development

```sh
nix develop
go test ./...
nix flake check
```

`go test ./e2e` runs the motions in the `vim` and `nvim` on your `PATH`, and skips an editor that is not installed.

## Special thanks

- [goda.vim](https://github.com/Shougo/goda.vim)
- [kagome](https://github.com/ikawaha/kagome)

## License

MIT

The binary embeds the IPA dictionary from [kagome-dict](https://github.com/ikawaha/kagome-dict). The Go code of kagome-dict is under the MIT License. The dictionary data is mecab-ipadic-2.7.0-20070801, which NAIST distributes under its own terms together with the ICOT Free Software conditions. The full text is in `NOTICE.txt` of the `github.com/ikawaha/kagome-dict/ipa` module.
