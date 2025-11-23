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
			-- Note: telescope integration removed (was mapped to 't')
			["g?"] = actions.help(),
		},
	}

	vim.keymap.set("n", "<m-s>", "<cmd>silent only | Navbuddy<cr>", { desc = "Open Navbuddy" })
	vim.keymap.set("n", "<m-o>", "<cmd>silent only | Navbuddy<cr>", { desc = "Open Navbuddy" })
end

return M
