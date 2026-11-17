// Command goda-wakachi serves the wakachi plugin to goda.vim.
package main

import (
	"github.com/Shougo/goda.vim/host"

	"github.com/airRnot1106/goda-wakachi.vim/internal/wakachi"
)

func main() {
	host.Main(wakachi.New())
}
