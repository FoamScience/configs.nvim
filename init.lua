-- general stuff
vim.loader.enable()
vim.g.loaded_netrw = 1                                                                                                                       
vim.g.loaded_netrwPlugin = 1 
require "user.base"
require "user.options"
require "user.keymaps"
require "user.autocmds"
spec "user.colorscheme"
spec "user.devicons"

-- TODO what else?

-- UX
spec "user.noice"
spec "user.significant"

-- lsp setup
spec "user.treesitter"
spec "user.comments"
spec "user.mason"
spec "user.lspconfig" -- most things after this require "user.lspicons"
spec "user.none-ls"
spec "user.treesj"
spec "user.todocomments"
spec "user.garbage"

-- git
spec "user.gitsigns"
spec "user.neogit"
spec "user.diffview"
spec "user.gitconflicts"
spec "user.blame"

-- winbar and statusline
spec "user.navic"
spec "user.lualine"
spec "user.unclutter"
spec "user.indentline"
spec "user.nvimtree"
spec "user.navbuddy"

-- telescope and autocompletion
spec "user.telescope"
spec "user.telescope-tabs"
spec "user.cmp"
spec "user.copilot"
spec "user.autopairs"

-- keymaps
spec "user.whichkey"
spec "user.arrow"
spec "user.dashboard"

-- AI
spec "user.sg"

-- projects
spec "user.project"

-- optionals for prettifying
spec "user.optional.colorizer"
spec "user.optional.dial"
spec "user.optional.dressing"
spec "user.optional.hop"
spec "user.optional.csv"
spec "user.optional.dim"
spec "user.optional.lens"
spec "user.optional.winsep"
spec "user.optional.neoscroll"


-- lazy needs to be loaded last
require "user.lazy"
require "user.ai"
