"
" TODO
"
" - support repeat.vim
"
" - when yanking in visual block mode, store a flag with the yanked text
"   that it was a blockwise yank. then, when that text is pasted, use setreg
"   with the 'b' option to make the paste work blockwise.
"

if !exists('s:yankstack') || !exists('g:yankstack_size') || !exists('s:last_paste')
  let s:yankstack = []
  let g:yankstack_size = 30
  let s:last_paste = { 'undo_number': -1 }
endif

function! g:yankstack(...)
  let list = [@@] + s:yankstack
  if a:0 == 0
    return list
  else
    let index = a:1 % len(list)
    return list[index]
  end
endfunction

function! s:substitute_paste(offset)
  if s:get_current_undo_number() != s:last_paste.undo_number
    echo 'Last change was not a paste'
  endif
  silent undo
  call s:move_stack_index(a:offset)
  call s:paste_from_yankstack()
endfunction

function! s:move_stack_index(offset)
  let s:last_paste.index += a:offset
  if s:last_paste.index < 0
    let s:last_paste.index = 0
  elseif s:last_paste.index >= len(g:yankstack())
    let s:last_paste.index = len(g:yankstack())-1
  endif
  echo 'Yank-stack index:' s:last_paste.index
endfunction

function! s:paste_from_yankstack()
  let [save_register, save_autoindent] = [@@, &autoindent]
  let [@@, &autoindent] = [g:yankstack(s:last_paste.index), 0]
  let s:last_paste.undo_number = s:get_next_undo_number()
  let command = (s:last_paste.mode == 'i') ? 'normal! a' : 'normal! '
  if s:last_paste.mode == 'i'
    silent exec 'normal! a' . s:last_paste.key
  elseif s:last_paste.mode == 'v'
    silent exec 'normal! gv' . s:last_paste.key
  else
    silent exec 'normal!' s:last_paste.key
  endif
  let [@@, &autoindent] = [save_register, save_autoindent]
endfunction

function! s:yank_with_key(key)
  call s:yankstack_add(@@)
  return a:key
endfunction

function! s:paste_with_key(key, mode)
  let index = 0
  if a:mode == 'v'
    call s:yankstack_add(@@)
    let index = 1
  endif
  let s:last_paste = {
    \ 'undo_number': s:get_next_undo_number(),
    \ 'key': a:key,
    \ 'index': index,
    \ 'mode': a:mode
    \ }
  return a:key
endfunction

function! s:get_next_undo_number()
  return undotree().seq_last + 1
endfunction

function! s:get_current_undo_number()
  let entries = undotree().entries
  if !empty(entries) && has_key(entries[-1], 'curhead')
    return s:get_parent_undo_number()
  else
    return undotree().seq_cur
  endif
endfunction

function! s:get_parent_undo_number()
  let entry = undotree().entries[-1]
  while has_key(entry, 'alt')
    let entry = entry.alt[0]
  endwhile
  return entry.seq - 1
endfunction

function! s:yankstack_add(item)
  let item_is_new = !empty(a:item) && empty(s:yankstack) || (a:item != s:yankstack[0])
  if item_is_new
    call insert(s:yankstack, a:item)
  endif
  let s:yankstack = s:yankstack[: g:yankstack_size-1]
endfunction

nnoremap <silent> <Plug>yankstack_substitute_older_paste  :call <SID>substitute_paste(1)<CR>
inoremap <silent> <Plug>yankstack_substitute_older_paste  <C-o>:call <SID>substitute_paste(1)<CR>
nnoremap <silent> <Plug>yankstack_substitute_newer_paste  :call <SID>substitute_paste(-1)<CR>
inoremap <silent> <Plug>yankstack_substitute_newer_paste  <C-o>:call <SID>substitute_paste(-1)<CR>
inoremap <expr>   <Plug>yankstack_insert_mode_paste       <SID>paste_with_key('<C-g>u<C-r>"', 'i')

let s:yank_keys  = ['x', 'y', 'd', 'c', 'X', 'Y', 'D', 'C', 'p', 'P']
let s:paste_keys = ['p', 'P']
for s:key in s:yank_keys
  exec 'noremap <expr> <Plug>yankstack_' . s:key '<SID>yank_with_key("' . s:key . '")'
endfor
for s:key in s:paste_keys
  exec 'nnoremap <expr> <Plug>yankstack_' . s:key '<SID>paste_with_key("' . s:key . '", "n")'
  exec 'vnoremap <expr> <Plug>yankstack_' . s:key '<SID>paste_with_key("' . s:key . '", "v")'
endfor

if !exists('g:yankstack_map_keys')
  let g:yankstack_map_keys = 1
endif

if g:yankstack_map_keys
  for s:key in s:yank_keys
    exec 'map' s:key '<Plug>yankstack_' . s:key
  endfor
  for s:key in s:paste_keys
    exec 'map' s:key '<Plug>yankstack_' . s:key
  endfor
  nmap [p    <Plug>yankstack_substitute_older_paste
  nmap ]p    <Plug>yankstack_substitute_newer_paste
  imap <M-y> <Plug>yankstack_substitute_older_paste
  imap <M-Y> <Plug>yankstack_substitute_newer_paste
  imap <C-y> <Plug>yankstack_insert_mode_paste
endif

