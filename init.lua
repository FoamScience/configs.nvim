-- general stuff
require "user.base"
require "user.options"
require "user.keymaps"
require "user.autocmds"
spec "user.colorscheme"
spec "user.devicons"

-- TODO what else?

-- lsp setup
spec "user.treesitter"
spec "user.comments"
spec "user.mason"
spec "user.lspconfig" -- most things after this require "user.lspicons"
spec "user.none-ls"
spec "user.treesj"
spec "user.todocomments"
spec "user.garbage"

-- winbar and statusline
spec "user.navic"
spec "user.lualine"
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
spec "user.harpoon"
spec "user.dashboard"

-- git
spec "user.gitsigns"
spec "user.neogit"
spec "user.diffview"
spec "user.gitconflicts"

-- projects
spec "user.project"

-- optionals for prettifying
spec "user.optional.colorizer"
spec "user.optional.dial"
spec "user.optional.dressing"
spec "user.optional.hop"
spec "user.optional.fugitive"
spec "user.optional.csv"
spec "user.optional.dim"
spec "user.optional.blame"
spec "user.optional.lens"
spec "user.optional.leetcode"
spec "user.optional.noice"

-- lazy needs to be loaded last
require "user.lazy"

-- Non-plugin stuff
require "user.ai"
