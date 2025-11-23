local M = {
	"folke/noice.nvim",
	event = "VeryLazy",  -- Changed from "uiEnter" for better startup time
	dependencies = {
		"MunifTanjim/nui.nvim",
		"grapp-dev/nui-components.nvim",
		"folke/snacks.nvim",
	},
}

function M.config()
	require("noice").setup({
		routes = {
			{ -- anything larger than 3 messages goes into a floating window
				view = "popup",
				filter = { event = "msg_show", min_height = 3 },
			},
		},
		lsp = {
			-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = false,
				["cmp.entry.get_documentation"] = true,
			},
			signature = {
				enabled = true,
				auto_open = {
					enabled = true,
					trigger = true,
					luasnip = true,
					throttle = 500, -- wait for 150ms beforeshowing hover info
				},
				opts = {
					zindex = 500,
				},
			},
		},
		notify = {
			enabled = false,
		},
		-- you can enable a preset for easier configuration
		presets = {
			bottom_search = false, -- use a classic bottom cmdline for search
			command_palette = true, -- position the cmdline and popupmenu together
			long_message_to_split = true, -- long messages will be sent to a split
			inc_rename = false,  -- enables an input dialog for inc-rename.nvim
			lsp_doc_border = true, -- add a border to hover docs and signature help
		},
		messages = {
			enabled = true,
			view_history = "popup",
		},
		popupmenu = { -- conflicts with cmp auto-completion
			enabled = false,
			backend = false,
		},
	})
end

return M
