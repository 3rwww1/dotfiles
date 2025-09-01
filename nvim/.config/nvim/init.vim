" Bridge Neovim to use your ~/.vimrc and native Vim packages
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" Bootstrap lazy.nvim in Neovim only (no effect for Vim)
let s:data_dir = stdpath('data')
if empty(glob(s:data_dir . '/lazy/lazy.nvim'))
  silent execute '!git clone --filter=blob:none https://github.com/folke/lazy.nvim ' . s:data_dir . '/lazy/lazy.nvim'
  autocmd VimEnter * ++once lua require('lazy').sync()
endif
set runtimepath^=~/.local/share/nvim/lazy/lazy.nvim

lua << EOF
require('lazy').setup({
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = { add = {text = '+'}, change = {text = '~'}, delete = {text = '_'}, topdelete = {text = '‾'}, changedelete = {text = '~'} },
    },
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { options = { theme = 'auto', icons_enabled = true } },
  },
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },
  {
    "filipjanevski/0x96f.nvim",
    config = function()
      require("0x96f").setup()
      vim.cmd.colorscheme("0x96f")
    end,
  }
})
EOF

highlight Normal ctermbg=NONE guibg=NONE
