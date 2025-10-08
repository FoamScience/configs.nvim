local M = {
	"folke/noice.nvim",
	event = "uiEnter",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"grapp-dev/nui-components.nvim"
	},
}

function M.config()
	require("noice").setup({
		routes = {
			{
				filter = {
					event = "msg_show",
					any = {
						{ find = "%d+L, %d+B" },
						{ find = "; after #%d+" },
						{ find = "; before #%d+" },
					},
				},
				view = "mini",
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
	})
end

return M
