if exists('g:loaded_goda_wakachi')
  finish
endif
let g:loaded_goda_wakachi = 1

nnoremap <Plug>(goda-wakachi-w) <Cmd>call goda_wakachi#move('w')<CR>
nnoremap <Plug>(goda-wakachi-b) <Cmd>call goda_wakachi#move('b')<CR>
nnoremap <Plug>(goda-wakachi-e) <Cmd>call goda_wakachi#move('e')<CR>
nnoremap <Plug>(goda-wakachi-ge) <Cmd>call goda_wakachi#move('ge')<CR>

xnoremap <Plug>(goda-wakachi-w) <Cmd>call goda_wakachi#move('w')<CR>
xnoremap <Plug>(goda-wakachi-b) <Cmd>call goda_wakachi#move('b')<CR>
xnoremap <Plug>(goda-wakachi-e) <Cmd>call goda_wakachi#move('e')<CR>
xnoremap <Plug>(goda-wakachi-ge) <Cmd>call goda_wakachi#move('ge')<CR>

" The v makes e and ge inclusive, as the native motions are.
onoremap <Plug>(goda-wakachi-w) <Cmd>call goda_wakachi#move('w')<CR>
onoremap <Plug>(goda-wakachi-b) <Cmd>call goda_wakachi#move('b')<CR>
onoremap <Plug>(goda-wakachi-e) v<Cmd>call goda_wakachi#move('e')<CR>
onoremap <Plug>(goda-wakachi-ge) v<Cmd>call goda_wakachi#move('ge')<CR>
