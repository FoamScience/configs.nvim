local M = {
	"folke/which-key.nvim",
	event = "VeryLazy",
}

function M.config()
    local icons = require("user.lspicons")
	local mappings = {
        ["b"] = { "<cmd>lua require('arrow.ui').openMenu()<CR>", icons.ui.History .. " Bookmarks" },
		["q"] = { "<cmd>confirm q<CR>", icons.ui.SignOut .. " Quit" },
		["e"] = { "<cmd>NvimTreeToggle<CR>", icons.ui.Folder .. " Explorer" },
		["o"] = { "<cmd>Navbuddy<cr>", icons.ui.Forward .. " Navigate" },
        ["m"] = { "<cmd>lua require('treesj').toggle()<cr>", icons.ui.Stacks .. "  Split/join code blocks"},

        c = {
            name = icons.misc.Robot .. " Cody",
            c = { "<cmd>CodyChat<cr>", "Code Chat" },
            t = { "<cmd>CodyToggle<cr>", "Toggle Cody window" },
        },

        d = {
            name = icons.git.Diff .. " Diffing",
            d = { "<cmd>DiffviewOpen<cr>", "Open Diff" },
            h = { "<cmd>DiffviewFileHistory<cr>", "File History" },
        },

		f = {
			name = icons.ui.Search .. " Find stuff",
			b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
			B = { "<cmd>Telescope buffers previewer=false<cr>", "Buffers"},
			c = { "<cmd>Telescope colorscheme<cr>", "Colorscheme" },
			f = { "<cmd>Telescope find_files<cr>", "Find files" },
			t = { "<cmd>Telescope live_grep<cr>", "Find Text" },
			s = { "<cmd>Telescope grep_string<cr>", "Find String" },
			h = { "<cmd>Telescope help_tags<cr>", "Help" },
			H = { "<cmd>Telescope highlights<cr>", "Highlights" },
			l = { "<cmd>Telescope resume<cr>", "Last Search" },
			M = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
			r = { "<cmd>Telescope oldfiles<cr>", "Recent File" },
			R = { "<cmd>Telescope registers<cr>", "Registers" },
			k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
			C = { "<cmd>Telescope commands<cr>", "Commands" },
		},

		g = {
			name = icons.git.Branch .. "  Git",
			g = { "<cmd>Neogit<cr>", "Neogit" },
			j = { "<cmd>lua require 'gitsigns'.next_hunk({navigation_message = false})<cr>", "Next Hunk" },
			k = { "<cmd>lua require 'gitsigns'.prev_hunk({navigation_message = false})<cr>", "Prev Hunk" },
			l = { "<cmd>lua require 'gitsigns'.blame_line()<cr>", "Blame" },
			p = { "<cmd>lua require 'gitsigns'.preview_hunk()<cr>", "Preview Hunk" },
			r = { "<cmd>lua require 'gitsigns'.reset_hunk()<cr>", "Reset Hunk" },
			R = { "<cmd>lua require 'gitsigns'.reset_buffer()<cr>", "Reset Buffer" },
			s = { "<cmd>lua require 'gitsigns'.stage_hunk()<cr>", "Stage Hunk" },
			u = {
				"<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>",
				"Undo Stage Hunk",
			},
			o = { "<cmd>Telescope git_status<cr>", "Open changed file" },
			b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
			c = { "<cmd>Telescope git_commits<cr>", "Checkout commit" },
			C = {
				"<cmd>Telescope git_bcommits<cr>",
				"Checkout commit(for current file)",
			},
			d = { "<cmd>Gitsigns diffthis HEAD<cr>", "Git Diff" },
            t = { "<cmd>DiffConflicts<cr>", "Diff Conflicts" }
		},

		l = {
			name = icons.kind.Class .. " LSP",
			a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Action" },
            d = { "<cmd>Telescope lsp_definitions<cr>", "Symbol definition" },
            D = { "<cmd>Telescope lsp_type_definitions<cr>", "Type definition" },
			f = { "<cmd>lua vim.lsp.buf.format({timeout_ms = 1000000})<cr>", "Format" },
			g = { "<cmd>Telescope diagnostics<cr>", "Diagnostics" },
			i = { "<cmd>LspInfo<cr>", "Info" },
			I = { "<cmd>Mason<cr>", "Mason Info" },
			j = {
				"<cmd>lua vim.diagnostic.goto_next()<cr>",
				"Next Diagnostic",
			},
			k = {
				"<cmd>lua vim.diagnostic.goto_prev()<cr>",
				"Prev Diagnostic",
			},

			l = { "<cmd>lua vim.lsp.codelens.run()<cr>", "CodeLens Action" },
			q = { "<cmd>lua vim.diagnostic.setloclist()<cr>", "Quickfix" },
			r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename" },
			R = { "<cmd>Telescope lsp_references<cr>", "References" },
			s = { "<cmd>Telescope lsp_document_symbols<cr>", "Document Symbols" },
			S = {
				"<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
				"Workspace Symbols",
			},
		},

        s = {
            name = icons.ui.Target .. " Sourcegraph",
            s = { "<cmd>lua require('sg.extensions.telescope').fuzzy_search_results()<cr>", "Search public code" },
        },

        t = {
            name = icons.ui.Telescope .. " Telescope",
            b = { "<cmd>Telescope buffers previewer=false<cr>", "Buffers"},
            f = { "<cmd>Telescope find_files<cr>", "Find files" },
			F = { "<cmd>Telescope git_file_history<cr>", "File history" },
            t = { "<cmd>Telescope live_grep<cr>", "Find Text" },
            s = { "<cmd>Telescope grep_string<cr>", "Find String" },
            h = { "<cmd>Telescope help_tags<cr>", "Help" },
            H = { "<cmd>Telescope highlights<cr>", "Highlights" },
            l = { "<cmd>Telescope resume<cr>", "Last Search" },
            p = { "<cmd>Telescope projects<cr>", "List projects" },
			P = { "<cmd>Telescope lazy_plugins<cr>", "Plugin configs" },
            u = { "<cmd>Telescope undo<cr>", "Unto tree" },
        },

		T = {
			name = icons.ui.Code .. "  TreeSitter",
			i = { "<cmd>TSConfigInfo<cr>", "Info" },
            t = { "<cmd>InspectTree<cr>", "Inspect Tree" },
		},

        w = {
            name = icons.ui.Watches .. "  Twilight",
            t = { "<cmd>Twilight<cr>", "Toggle" },
        },
	}

	local opts = {
		mode = "n", -- NORMAL mode
		prefix = "<leader>",
		buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
		silent = true, -- use `silent` when creating keymaps
		noremap = true, -- use `noremap` when creating keymaps
		nowait = true, -- use `nowait` when creating keymaps
	}

	-- NOTE: Prefer using : over <cmd> as the latter avoids going back in normal-mode.
	-- see https://neovim.io/doc/user/map.html#:map-cmd
	local vmappings = {
		["/"] = { "<Plug>(comment_toggle_linewise_visual)", "Comment toggle linewise (visual)" },
		l = {
			name = "LSP",
			a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Action" },
            e = { ":CodyExplain<cr>", "Cody Explain" },
		},
	}

	local vopts = {
		mode = "v", -- VISUAL mode
		prefix = "<leader>",
		buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
		silent = true, -- use `silent` when creating keymaps
		noremap = true, -- use `noremap` when creating keymaps
		nowait = true, -- use `nowait` when creating keymaps
	}

	local which_key = require "which-key"

	which_key.setup {
		plugins = {
			marks = true, -- shows a list of your marks on ' and `
			registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
			spelling = {
				enabled = true,
				suggestions = 20,
			}, -- use which-key for spelling hints
			-- the presets plugin, adds help for a bunch of default keybindings in Neovim
			-- No actual key bindings are created
			presets = {
				operators = true, -- adds help for operators like d, y, ...
				motions = false, -- adds help for motions
				text_objects = false, -- help for text objects triggered after entering an operator
				windows = true, -- default bindings on <c-w>
				nav = false, -- misc bindings to work with windows
				z = true, -- bindings for folds, spelling and others prefixed with z
				g = true, -- bindings for prefixed with g
			},
		},
		popup_mappings = {
			scroll_down = "<c-d>", -- binding to scroll down inside the popup
			scroll_up = "<c-u>", -- binding to scroll up inside the popup
		},
		window = {
			border = "single", -- none, single, double, shadow
			position = "bottom", -- bottom, top
			margin = { 1, 0, 1, 0 }, -- extra window margin [top, right, bottom, left]
			padding = { 1, 1, 1, 1 }, -- extra window padding [top, right, bottom, left]
			winblend = 0,
		},
		layout = {
			height = { min = 5, max = 25 }, -- min and max height of the columns
			width = { min = 20, max = 50 }, -- min and max width of the columns
			spacing = 1, -- spacing between columns
			align = "center", -- align columns left, center or right
		},
		ignore_missing = true, -- enable this to hide mappings for which you didn't specify a label
		hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ " }, -- hide mapping boilerplate
		show_help = false, -- show help message on the command line when the popup is visible
		show_keys = false, -- show the currently pressed key and its label as a message in the command line
		triggers = "auto", -- automatically setup triggers
		triggers_blacklist = {
			i = { "j", "k" },
			v = { "j", "k" },
		},
		-- disable the WhichKey popup for certain buf types and file types.
		-- Disabled by default for Telescope
		disable = {
			buftypes = {},
			filetypes = { "TelescopePrompt" },
		},
	}

	which_key.register(mappings, opts)
	which_key.register(vmappings, vopts)

	local m_opts = {
		mode = "n", -- NORMAL mode
		prefix = "m",
		buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
		silent = true, -- use `silent` when creating keymaps
		noremap = true, -- use `noremap` when creating keymaps
		nowait = true, -- use `nowait` when creating keymaps
	}

	local m_mappings = {
	}

	which_key.register(m_mappings, m_opts)
end

return M
