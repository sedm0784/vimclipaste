let s:file_types = {
      \ 'png': {'extension': '.png', 'applescript_type': '«class PNGf»'},
      \ 'jpeg': {'extension': '.jpeg', 'applescript_type': 'JPEG picture'},
      \ 'gif': {'extension': '.gif', 'applescript_type': 'GIF picture'}
      \ }

function! vimclipaste#paste_clipboard_image(after) abort
  let destination_dir = get(b:, 'vimclipaste_destination_dir', 'images')
  let image_name = get(b:, 'vimclipaste_image_name', 'image')
  let file_type = get(b:, 'vimclipaste_file_type', 'png')
  let markup = get(b:, 'vimclipaste_markup', '[$cursor]($path)')

  if destination_dir[-1:] != '/'
    let destination_dir .= '/'
  endif
  let file_type = tolower(file_type)
  if file_type == 'jpg'
    let file_type = 'jpeg'
  endif
  let extension = s:file_types[file_type]['extension']

  if get(b:, 'vimclipaste_imgur', 0) == 0
    " Create destination directory if it doesn't exist
    if !isdirectory(destination_dir)
      silent call mkdir(destination_dir, 'p')
    endif
  endif

  " First find out what file name to use
  let index = 1
  let file_path = destination_dir . image_name . index . extension
  while filereadable(file_path)
    let index = index + 1
    let file_path = destination_dir . image_name . index . extension
  endwhile

  " FIXME: Use $$path in case the user actually wants $path in their markup?
  let pos = match(markup, '$path')
  if pos == -1
    echom "Bad markup: no $path"
    return
  endif
  if pos == 0
    let markup = file_path . markup[pos+5:]
  else
    let markup = markup[:pos-1] . file_path . markup[pos+5:]
  endif

  " N.B. $cursor at the end is the same as no $cursor, and leaves the cursor
  " *on* the final character of the paste (which is the same behaviour as a
  " regular paste.
  let cursor_pos = match(markup, '$cursor')
  if cursor_pos != -1
    if cursor_pos == 0
      let markup = markup[cursor_pos+7:]
    else
      let markup = markup[:cursor_pos-1] . markup[cursor_pos+7:]
    endif
    " Invert position: we start from end of string
    " FIXME: Check edge cases!
    let cursor_pos = len(markup) - (cursor_pos + 1)
  endif

  " Save the clipboard to a file
  let saved = vimclipaste#save_clipboard(file_path, file_type)

  if saved
    execute 'normal! ' . (a:after ? 'a' : 'i') . markup
    if cursor_pos > 0
      execute 'normal! ' . cursor_pos . 'h'
    endif
  else
    execute 'normal! "+' . (a:after ? 'p' : 'P')
  endif
endfunction

" FIXME: Implement other save mechanisms for cross-platform vimclipasting:
"        - Python/Pillow
"        - xclip
function! vimclipaste#save_clipboard(file_path, file_type) abort
  if a:file_path[0] == '/'
    let file_path = a:file_path
  else
    let file_path = getcwd() . '/' . a:file_path
  endif

  let clip_command = 'osascript'
        \. ' -e "set image_data to the clipboard as '
        \. s:file_types[a:file_type]['applescript_type'] . '"'
        \. ' -e "set file_ref to open for access POSIX path of'
        \. ' (POSIX file \"' . file_path . '\") with write permission"'
        \. ' -e "write image_data to file_ref"'

  silent call system(clip_command)

  return v:shell_error == 0
endfunction
