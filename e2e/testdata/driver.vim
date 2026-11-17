" Runs the cases of $GODA_WAKACHI_E2E_CASES in a real editor and writes what
" it saw to $GODA_WAKACHI_E2E_OUT.
set encoding=utf-8
let &runtimepath = join(map([$GODA_WAKACHI_E2E_PLUGIN, $GODA_WAKACHI_E2E_GODA], {_, dir -> escape(dir, ',')}) + [&runtimepath], ',')
runtime plugin/goda_wakachi.vim

for s:mode in ['n', 'x', 'o']
  for s:motion in ['w', 'b', 'e', 'ge']
    execute s:mode . 'map' s:motion '<Plug>(goda-wakachi-' . s:motion . ')'
  endfor
endfor

function! s:thrown(expr) abort
  try
    call eval(a:expr)
  catch
    return v:exception
  endtry
  return ''
endfunction

let s:result = #{cases: {}}

try
  for s:case in json_decode(join(readfile($GODA_WAKACHI_E2E_CASES), "\n"))
    let g:goda_wakachi#unit = s:case.unit
    %delete _
    call setline(1, s:case.lines)
    call cursor(s:case.cursor[0], s:case.cursor[1])
    let @" = ''
    call feedkeys(s:case.keys, 'tx')
    let s:result.cases[s:case.name] = #{
          \ cursor: [line('.'), col('.')],
          \ lines: getline(1, '$'),
          \ yank: @",
          \}
  endfor

  unlet g:goda_wakachi#unit
  let s:result.segments = goda_wakachi#segment('私は学校に行く')
  let s:result.morphemes = goda_wakachi#segment('私は学校に行く', 'morpheme')
  let s:result.unknown_unit = s:thrown("goda_wakachi#segment('猫', 'sentence')")
catch
  let s:result.error = v:exception . ' at ' . v:throwpoint
endtry

call writefile([json_encode(s:result)], $GODA_WAKACHI_E2E_OUT)
qall!
