local M = {
	--"catppuccin/nvim",
	--"p00f/alabaster.nvim",
    "Shatur/neovim-ayu",
	lazy = false, -- load at startup cuz it's the main colorscheme
	priority = 1000, -- load it before anything else
}

function M.config()
	--vim.cmd.colorscheme "catppuccin"
	--vim.cmd.colorscheme "alabaster"
    local colors = require('ayu.colors')
    colors.generate()
    colors.black = colors.bg
    colors.panel_border = colors.bg
    colors.panel_shadow = colors.bg
    require("ayu").setup({
        mirage = false,
        overrides = {
            CursorLine = { bg = colors.panel_bg },
            CursorLineNr = { bg = colors.panel_bg },
            StatusLine = { bg = colors.panel_bg },
            TabLineFill = { bg = colors.panel_bg },
        }
    })
    local custom_ayu = require("lualine.themes.ayu")
    custom_ayu.normal.c.bg = colors.bg
    require("lualine").setup({
        options = {
            theme = custom_ayu,
        }
    })
	vim.cmd.colorscheme "ayu"
end

return M
