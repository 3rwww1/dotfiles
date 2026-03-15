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
-- Set leader key before plugins load
vim.g.mapleader = " "

-- Disable netrw early (before nvim-tree loads)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require('lazy').setup({
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup({
        signs = { add = {text = '+'}, change = {text = '~'}, delete = {text = '_'}, topdelete = {text = '‾'}, changedelete = {text = '~'}, untracked = {text = '?'} },
        sign_priority = 6,
        attach_to_untracked = true,
        on_attach = function(bufnr)
          local gs = require('gitsigns')
          local opts = function(desc) return { buffer = bufnr, desc = desc } end
          vim.keymap.set('n', ']c', function() gs.nav_hunk('next') end, opts('Next hunk'))
          vim.keymap.set('n', '[c', function() gs.nav_hunk('prev') end, opts('Prev hunk'))
          vim.keymap.set('n', '<leader>hp', gs.preview_hunk, opts('Preview hunk'))
          vim.keymap.set('n', '<leader>hs', gs.stage_hunk, opts('Stage hunk'))
          vim.keymap.set('n', '<leader>hr', gs.reset_hunk, opts('Reset hunk'))
          vim.keymap.set('n', '<leader>hb', function() gs.blame_line({ full = true }) end, opts('Blame line'))
        end,
      })
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local grey = { fg = '#cccccc', bg = '#303030' }
      local gold = { fg = '#262427', bg = '#af8700', gui = 'bold' }
      local theme = {
        normal   = { a = gold, b = grey, c = grey },
        insert   = { a = gold, b = grey, c = grey },
        visual   = { a = gold, b = grey, c = grey },
        replace  = { a = gold, b = grey, c = grey },
        command  = { a = gold, b = grey, c = grey },
        inactive = { a = grey, b = grey, c = grey },
      }
      require('lualine').setup({
        options = {
          theme = theme,
          icons_enabled = true,
          section_separators = '',
          component_separators = '',
          disabled_filetypes = { statusline = { 'NvimTree' } },
        },
      })
    end,
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
      -- Override after colorscheme: transparent bg + white separator
      local transparent = { "Normal", "NormalNC", "NvimTreeNormal", "NvimTreeNormalNC", "NvimTreeEndOfBuffer", "SignColumn", "EndOfBuffer" }
      for _, g in ipairs(transparent) do
        vim.api.nvim_set_hl(0, g, { bg = "NONE" })
      end
      vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#808080", bg = "NONE" })
      vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { fg = "#808080", bg = "NONE" })
      vim.api.nvim_set_hl(0, "NvimTreeVertSplit", { fg = "#808080", bg = "NONE" })
      -- Match eza colors (Ghostty ANSI palette)
      vim.api.nvim_set_hl(0, "NvimTreeFolderIcon", { fg = "#81a2be" })
      vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = "#81a2be" })
      vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = "#81a2be", bold = true })
      vim.api.nvim_set_hl(0, "NvimTreeExecFile", { fg = "#b5bd68", bold = true })
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 35,
        },
        renderer = {
          icons = {
            show = {
              file = true,
              folder = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,  -- show hidden files
        },
        git = {
          enable = true,
          ignore = false,    -- show .gitignored files (dimmed)
        },
      })
    end,
  },
  -- Terminal (for shell + Claude Code)
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        open_mapping = [[<C-\>]],
        direction = "horizontal",
        size = 20,
        shade_terminals = true,
      })

      -- Named terminal for Claude Code
      local Terminal = require("toggleterm.terminal").Terminal
      local claude = Terminal:new({
        cmd = "claude",
        direction = "vertical",
        dir = "git_dir",
        close_on_exit = false,
      })
      vim.keymap.set("n", "<leader>cc", function() claude:toggle() end, { desc = "Toggle Claude Code" })
    end,
  },

  -- Claude Code IDE integration (WebSocket protocol)
  {
    "coder/claudecode.nvim",
    config = function()
      require("claudecode").setup()
    end,
  },

  -- LSP: auto-install language servers
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "gopls",           -- Go
          "rust_analyzer",   -- Rust
          "pyright",         -- Python
          "ruby_lsp",        -- Ruby
          "bashls",          -- Bash
          "terraformls",     -- Terraform
        },
      })
    end,
  },

  -- LSP: config for each language server
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      -- Shared keymaps: these activate when an LSP attaches to a buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }

          -- Navigation
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)         -- go to definition
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)         -- find references
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)     -- go to implementation
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)               -- show docs popup

          -- Refactoring
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)           -- rename symbol
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)      -- code actions
          vim.keymap.set("n", "<leader>fm", function()                          -- format file
            vim.lsp.buf.format({ async = true })
          end, opts)

          -- Diagnostics
          vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, opts)
          vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, opts)
          vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, opts)    -- show error detail
        end,
      })

      -- Enable each server (nvim 0.11+ native API)
      local servers = { "gopls", "rust_analyzer", "pyright", "ruby_lsp", "bashls", "terraformls" }
      for _, server in ipairs(servers) do
        vim.lsp.enable(server)
      end
    end,
  },
})

-- Keymaps
-- Use system clipboard for yank/paste
vim.o.clipboard = "unnamedplus"

-- Always show sign column so gitsigns are visible
vim.o.signcolumn = "yes"

-- Auto-reload files changed externally
vim.o.autoread = true
vim.o.updatetime = 1000
vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "CursorHold"}, { command = "checktime" })

vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
vim.keymap.set("n", "<leader>f", "<cmd>NvimTreeFindFile<cr>", { desc = "Find current file in tree" })

EOF
