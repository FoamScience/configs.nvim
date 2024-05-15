local M = {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make", lazy = true },
		{ "nvim-telescope/telescope-symbols.nvim" },
		{ "polirritmico/telescope-lazy-plugins.nvim" },
		{ "isak102/telescope-git-file-history.nvim", dependencies = { "tpope/vim-fugitive" } },
		{ "debugloop/telescope-undo.nvim" },
	},
	lazy = true,
	cmd = "Telescope",
}

function M.config()
	local icons = require("user.lspicons")
	local actions = require("telescope.actions")
	local layout_ops = {
		layout_config = {
			horizontal = {
				prompt_position = "top",
				preview_width = 0.55,
			},
			vertical = {
				mirror = false,
			},
			width = 0.87,
			height = 0.80,
			preview_cutoff = 120,
		},
		layout_strategy = "flex",
        winblend = 0,
        border = {},
	}

	require("telescope").setup({
		defaults = {
			prompt_prefix = icons.ui.Telescope .. " ",
			selection_caret = icons.ui.Forward .. " ",
			entry_prefix = "   ",
			initial_mode = "insert",
			selection_strategy = "reset",
			path_display = { "smart" },
			color_devicons = true,
			set_env = { ["COLORTERM"] = "truecolor" },
			sorting_strategy = nil,
			layout_strategy = nil,
			layout_config = {
				width = 0.95,
			},
			vimgrep_arguments = {
				"rg",
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
				"--smart-case",
				"--hidden",
				"--glob=!.git/",
			},

			mappings = {
				i = {
					["<C-n>"] = actions.cycle_history_next,
					["<C-p>"] = actions.cycle_history_prev,

					["<C-j>"] = actions.move_selection_next,
					["<C-k>"] = actions.move_selection_previous,
				},
				n = {
					["<esc>"] = actions.close,
					["j"] = actions.move_selection_next,
					["k"] = actions.move_selection_previous,
					["q"] = actions.close,
				},
			},
		},
		pickers = {
			live_grep = vim.tbl_extend("force", layout_ops, {
				previewer = true,
			}),

			grep_string = vim.tbl_extend("force", layout_ops, {
				previewer = true,
			}),

			find_files = vim.tbl_extend("force", layout_ops, {
				previewer = true,
			}),

			buffers = {
				theme = "dropdown",
				previewer = false,
				initial_mode = "normal",
				mappings = {
					i = {
						["<C-d>"] = actions.delete_buffer,
					},
					n = {
						["dd"] = actions.delete_buffer,
					},
				},
			},

			colorscheme = {
				enable_preview = true,
			},

			lsp_references = {
				theme = "dropdown",
				initial_mode = "normal",
			},

			lsp_definitions = {
				theme = "dropdown",
				initial_mode = "normal",
			},

			lsp_declarations = {
				theme = "dropdown",
				initial_mode = "normal",
			},

			lsp_implementations = {
				theme = "dropdown",
				initial_mode = "normal",
			},
		},
		extensions = {
			fzf = {
				fuzzy = true, -- false will only do exact matching
				override_generic_sorter = true, -- override the generic sorter
				override_file_sorter = true, -- override the file sorter
				case_mode = "smart_case", -- or "ignore_case" or "respect_case"
			},
			lazy_plugins = {},
			git_file_history = {},
			undo = {
				use_delta = true,
				diff_context_lines = 10,
			},
		},
	})
end

return M
