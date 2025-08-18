" Minimal, sensible Vim defaults (no plugins, no theme)
set nocompatible
syntax on
filetype plugin indent on

" UI
set number
set ambiwidth=double
set display+=uhex

" Indentation (2 spaces by default; adjust per language as needed)
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab

" Search
set ignorecase
set smartcase
set incsearch
set hlsearch

" Files
set noswapfile

" Mouse (enable basic mouse support in terminals)
set mouse=a

" Whitespace: highlight trailing spaces
highlight RedundantSpaces ctermbg=red guibg=red
match RedundantSpaces /\s\+$/
