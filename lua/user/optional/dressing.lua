local M = {
	"stevearc/dressing.nvim",
	event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" }
}

function M.config()
	require("dressing").setup {
		input = {
			enabled = true,
			default_prompt = "Input:",
			title_pos = "left",
			insert_only = true,
			start_in_insert = true,
			border = "none",
			relative = "cursor",
			prefer_width = 40,
			width = nil,
			max_width = { 140, 0.9 },
			min_width = { 20, 0.2 },

			buf_options = {},
			win_options = {
				winblend = 10,
				wrap = false,
				list = true,
				listchars = "precedes:…,extends:…",
				sidescrolloff = 0,
			},
		},
		select = {
			enabled = true,
			backend = { "nui", "telescope", "fzf_lua", "fzf", "builtin" },
			trim_prompt = true,
			nui = {
				position = "50%",
				size = nil,
				relative = "editor",
				border = {
					style = "rounded",
				},
				buf_options = {
					swapfile = false,
					filetype = "DressingSelect",
				},
				win_options = {
					winblend = 10,
				},
				max_width = 80,
				max_height = 40,
				min_width = 40,
				min_height = 10,
			},
			builtin = {
				border = "none",
				relative = "editor",
				buf_options = {},
				win_options = {
					winblend = 10,
					cursorline = true,
					cursorlineopt = "both",
				},
				width = nil,
				max_width = { 140, 0.8 },
				min_width = { 40, 0.2 },
				height = nil,
				max_height = 0.9,
				min_height = { 10, 0.2 },
				mappings = {
					["<Esc>"] = "Close",
					["<C-c>"] = "Close",
					["<CR>"] = "Confirm",
				},

			},
		},
	}
end

return M
