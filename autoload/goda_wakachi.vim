let s:root = expand('<sfile>:p:h:h')
let s:cache = {}
let s:cache_max = 1000

" edge is the index into a [start, last] segment where the motion lands.
" empty says whether the motion stops on an empty line.
let s:motions = #{
      \ w: #{forward: v:true, edge: 0, empty: v:true},
      \ b: #{forward: v:false, edge: 0, empty: v:true},
      \ e: #{forward: v:true, edge: 1, empty: v:false},
      \ ge: #{forward: v:false, edge: 1, empty: v:true},
      \}

function! s:start() abort
  let bins = exists('g:goda_wakachi#binary') ? [g:goda_wakachi#binary] : []
  let bins += [s:root . '/bin/goda-wakachi', s:root . '/result/bin/goda-wakachi']
  for bin in bins
    if executable(bin)
      call goda#start(bin)
      return
    endif
  endfor
  throw 'goda-wakachi: no binary found, run nix build in ' . s:root . ' or see :help goda-wakachi-install'
endfunction

" goda keeps a failed start until the next goda#register(), and a later motion
" has to see a binary built in the meantime.
function! s:register() abort
  if !goda#is_running('wakachi')
    call goda#register('wakachi', function('s:start'),
          \ #{version: 1, module: 'github.com/airRnot1106/goda-wakachi.vim'})
  endif
endfunction

function! s:segments(text, unit) abort
  if a:text ==# ''
    return []
  endif
  let key = a:unit . "\n" . a:text
  if !has_key(s:cache, key)
    call s:register()
    let segments = goda#request('wakachi', 'segment', a:text, a:unit)
    if len(s:cache) >= s:cache_max
      let s:cache = {}
    endif
    let s:cache[key] = segments
  endif
  return s:cache[key]
endfunction

function! s:unit() abort
  return get(g:, 'goda_wakachi#unit', 'bunsetsu')
endfunction

function! goda_wakachi#segment(text, ...) abort
  return deepcopy(s:segments(a:text, a:0 ? a:1 : s:unit()))
endfunction

" The 0-based byte offset of the last character of line lnum.
function! s:last_col(lnum) abort
  let text = getline(a:lnum)
  return strlen(text) - strlen(strcharpart(text, strchars(text) - 1))
endfunction

" The columns of line lnum where motion lands, in the order it meets them.
function! s:stops(lnum, motion) abort
  let cols = map(copy(s:segments(getline(a:lnum), s:unit())), {_, segment -> segment[a:motion.edge]})
  return a:motion.forward ? cols : reverse(cols)
endfunction

" The [lnum, col] one step of motion away from pos, or [] at the end of the
" buffer.
function! s:step(pos, motion) abort
  let [lnum, col] = a:pos
  for stop in s:stops(lnum, a:motion)
    if a:motion.forward ? stop > col : stop < col
      return [lnum, stop]
    endif
  endfor
  let lnums = a:motion.forward ? range(lnum + 1, line('$')) : range(lnum - 1, 1, -1)
  for lnum in lnums
    let stops = s:stops(lnum, a:motion)
    if !empty(stops)
      return [lnum, stops[0]]
    endif
    if a:motion.empty && getline(lnum) ==# ''
      return [lnum, 0]
    endif
  endfor
  return []
endfunction

function! goda_wakachi#move(motion) abort
  let cnt = v:count1
  " A line with no multibyte character has no bunsetsu to find. An empty line
  " stays here, because the line next to it may be Japanese.
  if getline('.') =~# '^[\x01-\x7f]\+$'
    execute 'normal!' cnt . a:motion
    return
  endif

  let motion = s:motions[a:motion]
  let pos = [line('.'), col('.') - 1]
  let from = pos
  let overrun = v:false
  for _ in range(cnt)
    let next = s:step(pos, motion)
    if empty(next)
      let overrun = v:true
      break
    endif
    let [from, pos] = [pos, next]
  endfor
  if overrun
    let from = pos
    let pos = motion.forward ? [line('$'), s:last_col(line('$'))] : [1, 0]
  endif

  " As with the native dw, the operator ends at the end of the line and does
  " not join the next line.
  if a:motion ==# 'w' && mode(1) =~# '^no' && (overrun || pos[0] != from[0])
    normal! v
    call cursor(from[0], s:last_col(from[0]) + 1)
    return
  endif
  call cursor(pos[0], pos[1] + 1)
endfunction
