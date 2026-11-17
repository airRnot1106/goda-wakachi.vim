" Run by drive.sh after the vimrc of the flake, which loads goda.vim and the
" plugin and maps the motions to w, b, e and ge.
set encoding=utf-8

let s:keys = $GODA_WAKACHI_VERIFY_KEYS
let s:cursor = map(split($GODA_WAKACHI_VERIFY_CURSOR, ','), 'str2nr(v:val)')
let s:result = #{
      \ feature: $GODA_WAKACHI_VERIFY_FEATURE,
      \ name: $GODA_WAKACHI_VERIFY_NAME,
      \ editor: filter(split(execute('version'), "\n"), 'v:val !=# ""')[0],
      \ keys: s:keys,
      \ unit: $GODA_WAKACHI_VERIFY_UNIT,
      \ pre: $GODA_WAKACHI_VERIFY_PRE,
      \}

function! s:state() abort
  return #{cursor: [line('.'), col('.')], lines: getline(1, '$'), yank: @", mode: mode(1)}
endfunction

try
  if $GODA_WAKACHI_VERIFY_UNIT !=# ''
    let g:goda_wakachi#unit = $GODA_WAKACHI_VERIFY_UNIT
  endif
  if $GODA_WAKACHI_VERIFY_PRE !=# ''
    execute $GODA_WAKACHI_VERIFY_PRE
  endif
  call setline(1, readfile($GODA_WAKACHI_VERIFY_LINES))
  call cursor(s:cursor[0], s:cursor[1])
  let @" = ''
  let s:result.before = s:state()
  if s:keys !=# ''
    execute 'call feedkeys("' . escape(s:keys, '"') . '", "tx")'
  endif
  let s:result.after = s:state()
  if $GODA_WAKACHI_VERIFY_EXPR !=# ''
    let s:result.expr = #{source: $GODA_WAKACHI_VERIFY_EXPR, value: eval($GODA_WAKACHI_VERIFY_EXPR)}
  endif
catch
  let s:result.error = v:exception . ' at ' . v:throwpoint
endtry

try
  let s:result.plugins = goda#plugins()
  let s:result.log = goda#log()
catch
  let s:result.goda_error = v:exception
endtry

call writefile([json_encode(s:result)], $GODA_WAKACHI_VERIFY_OUT)
qall!
