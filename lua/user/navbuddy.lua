local M = {
	"SmiteshP/nvim-navbuddy",
    event = "VeryLazy",
	dependencies = {
		"SmiteshP/nvim-navic",
		"MunifTanjim/nui.nvim",
	},
}

function M.config()
	local navbuddy = require "nvim-navbuddy"
	local actions = require("nvim-navbuddy.actions")
	navbuddy.setup {
		window = {
			border = "rounded",
            size = "80%",
		},
		icons = require("user.lspicons").kind,
		lsp = { auto_attach = true },
		mappings = {
			["<esc>"] = actions.close(),
			["q"] = actions.close(),
            ["<Down>"] = actions.next_sibling(),
            ["<Up>"] = actions.previous_sibling(),
            ["<Right>"] = actions.children(),
            ["<Left>"] = actions.parent(),
            ["c"] = actions.comment(),
            ["s"] = actions.toggle_preview(),
            ["<C-v>"] = actions.vsplit(),
            ["t"] = actions.telescope({
                layout_config = {
                    height = 0.60,
                    width = 0.60,
                    prompt_position = "top",
                    preview_width = 0.50
                },
                layout_strategy = "horizontal"
            }),
            ["g?"] = actions.help(),
		},
	}

	local opts = { noremap = true, silent = true }
	local keymap = vim.api.nvim_set_keymap

	keymap("n", "<m-s>", ":silent only | Navbuddy<cr>", opts)
	keymap("n", "<m-o>", ":silent only | Navbuddy<cr>", opts)
end

return M
