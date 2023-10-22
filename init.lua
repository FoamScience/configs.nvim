-- general stuff
require "user.base"
require "user.options"
require "user.keymaps"
require "user.autocmds"
spec "user.colorscheme"
spec "user.devicons"

-- lsp setup
spec "user.treesitter"
spec "user.mason"
spec "user.lspconfig" -- most things after this require "user.lspicons"
spec "user.none-ls"

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

-- git
spec "user.gitsigns"
spec "user.neogit"
spec "user.diffview"

-- projects
spec "user.project"

-- optionals for prettifying
spec "user.optional.colorizer"
spec "user.optional.dial"
--spec "user.extras.nui"
--spec "user.extras.dressing"
--spec "user.extras.surround"
--spec "user.extras.eyeliner"
--spec "user.extras.numb"
--spec "user.extras.jaq"
--spec "user.extras.minifiles"
---- spec "user.extras.noice"
--spec "user.extras.cmp-tabnine"
--spec "user.extras.lab"
--spec "user.extras.tabby"
---- spec "user.extras.test"
---- spec "user.extras.typescript-tools"
--spec "user.extras.gitlinker"
--spec "user.extras.fugitive"
--spec "user.extras.bookmark"
--spec "user.extras.trailblazer"
-- lazy needs to be loaded last
require "user.lazy"

-- local colors = vim.fn.getcompletion("", "color")
-- vim.cmd("colorscheme " .. colors[math.random(1, #colors)])
