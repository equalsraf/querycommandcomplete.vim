" Query Command Complete
" ======================
"
" Vim plugin to suggest completions with the results of an external
" query command.
"
" The original intention is to use it as a mutt query_command wrapper
" to complete addresses in the mail headers, but it can be adapted
" to any other kind of functionality by modifying the exposed setting
" parameters.
"
" Last Change: 2012 Dec 29
" Author: Caio Romão <caioromao@gmail.com>
" License: This file is placed in the public domain
" Contributors:
"   Brian Henderson <https://github.com/bhenderson>
"   Mark Stillwell <https://github.com/marklee77>
"
" Setup:
"   This plugin exports the completion function QueryCommandComplete,
"   which can be set as the complete function (or omni function) for
"   any filetype. If you have a working mutt setup with query_command
"   configured, the plugin works out of the box.
"
"   Example:
"       let g:qcc_query_command='abook'
"       au BufRead /tmp/mutt* setlocal omnifunc=QueryCommandComplete
"
" Settings:
"   g:qcc_query_command
"       External command that queries for contacts
"       If empty, QueryCommandComplete tries to guess what command to
"       run by executing `mutt -Q query_command`.
"
"   g:qcc_line_separator
"       Separator for each entry in the result from the query
"       default: '\n'
"
"   g:qcc_field_separator
"       Separator for the fields of an entry from the result
"       default: '\t'
"
"   g:qcc_pattern
"       Pattern used to match against the current line to decide
"       whether to call the query command
"       default: '^\(To\|Cc\|Bcc\|From\|Reply-To\):'
"
"   g:qcc_multiline
"       Whether to try matching g:qcc_pattern against the current
"       and any previous line
"       default: 0
"
"   g:qcc_multiline_pattern
"       Pattern to match against the current line when deciding
"       wether to keep looking for a line that matches g:qcc_pattern
"       This provides finer control over the recursion, which
"       is useful if calling the completion on really big files.
"       default: '.*'

if exists("g:loaded_QueryCommandComplete") || &cp
  finish
endif

" Try to use mutt's query_command by default if nothing is set
if !exists("g:qcc_query_command")
    let s:querycmd = system('mutt -Q query_command 2>/dev/null')
    let s:querycmd = substitute(s:querycmd, '^query_command="\(.*\)"\n', '\1','')

    if len(s:querycmd)
        let g:qcc_query_command = s:querycmd
        let g:qcc_multiline = 1
        autocmd FileType mail setlocal omnifunc=QueryCommandComplete
    else
        echoerr "QueryCommandComplete: g:qcc_query_command not set!"
        finish
    endif
endif

let g:loaded_QueryCommandComplete = 1
let s:save_cpo = &cpo
set cpo&vim

function! s:DefaultIfUnset(name, default)
    if !exists(a:name)
        let {a:name} = a:default
    endif
endfunction

call s:DefaultIfUnset('g:qcc_line_separator', '\n')
call s:DefaultIfUnset('g:qcc_field_separator', '\t')
call s:DefaultIfUnset('g:qcc_pattern', '^\(To\|Cc\|Bcc\|From\|Reply-To\):')
call s:DefaultIfUnset('g:qcc_multiline', 0)
call s:DefaultIfUnset('g:qcc_multiline_pattern', '.*')

function! s:MakeCompletionEntry(name, email, other)
    let entry = {}
    let entry.word = a:name . ' <' . a:email . '>'
    let entry.abbr = a:name
    let entry.menu = a:other
    let entry.icase = 1
    return entry
endfunction

function! s:FindStartingIndex()
    let cur_line = getline('.')

    " locate the start of the word
    let start = col('.') - 1
    while start > 0 && cur_line[start - 1] =~ '[^:,]'
        let start -= 1
    endwhile

    " lstrip()
    while cur_line[start] =~ '[ ]'
        let start += 1
    endwhile

    return start
endfunction

function! s:GenerateCompletions(findstart, base)
    if a:findstart
        return s:FindStartingIndex()
    endif

    let results = []
    let cmd = g:qcc_query_command
    if cmd !~ '%s'
        let cmd .= ' %s'
    endif
    let cmd = substitute(cmd, '%s', shellescape(a:base), '')
    let lines = split(system(cmd), g:qcc_line_separator)

    for my_line in lines
        let fields = split(my_line, g:qcc_field_separator)

        if (len(fields) < 2)
            continue
        endif

        let email = fields[0]
        let name = fields[1]
        let other = ''

        if (len(fields) > 2)
            let other = fields[2]
        endif

        let contact = s:MakeCompletionEntry(name, email, other)

        call add(results, contact)
    endfor

    return results
endfunction

function! s:ShouldGenerateCompletions(line_number)
    let current_line = getline(a:line_number)

    if current_line =~ g:qcc_pattern
        return 1
    endif

    if ! g:qcc_multiline || a:line_number <= 1 || current_line !~ g:qcc_multiline_pattern
        return 0
    endif

    return s:ShouldGenerateCompletions(a:line_number - 1)
endfunction

function! QueryCommandComplete(findstart, base)
    if s:ShouldGenerateCompletions(line('.'))
        return s:GenerateCompletions(a:findstart, a:base)
    endif
endfunction

let &cpo = s:save_cpo
