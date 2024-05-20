local M = {
	"lukas-reineke/indent-blankline.nvim",
    main = "ibl",
	event = "VeryLazy",
}

function M.config()
	local icons = require "user.lspicons"

	require("ibl").setup {
        indent = {
            smart_indent_cap = true,
		    char = icons.ui.LineMiddle,
		    tab_char = icons.ui.LineMiddle,
        },
        exclude = {
		    filetypes = {
                "lspinfo",
                "checkhealth",
		    	"help",
                "man",
                "gitcommit",
		    	"dashboard",
                "TelescopePrompt",
                "TelescopeResults",
		    	"lazy",
		    	"neogitstatus",
		    	"NvimTree",
		    	"text",
		    },
        },
	}
end

return M
