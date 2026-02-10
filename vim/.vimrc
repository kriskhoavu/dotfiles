set incsearch
set expandtab
set tabstop=4
set scrolloff=5
set shiftwidth=4

map Q gq

" Cursor settings
set ttimeout
set ttimeoutlen=10
set clipboard=unnamed,unnamedplus
let &t_EI = "\e[2 q"
let &t_SI = "\e[6 q"
set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50

" Replace helpers
nnoremap gR gD:%s/<C-R>///gc<left><left><left> " whole file
nnoremap gr gd[{V%::s/<C-R>///gc<left><left><left> " inside block

" Wrap helpers () {} '' ""
vnoremap <leader>( <Esc>`<i(<Esc>`>a)<Esc>
vnoremap <leader>[ <Esc>`<i[<Esc>`>a]<Esc>
vnoremap <leader>q <Esc>`<i'<Esc>`>a'<Esc>
vnoremap <leader>" <Esc>`<i"<Esc>`>a"<Esc>

" Paste without overwriting yank buffer
xnoremap <leader>p "_dP"

" Move selected lines
xnoremap J :m '>+1<CR>gv=gv
xnoremap K :m '<-2<CR>gv=gv

