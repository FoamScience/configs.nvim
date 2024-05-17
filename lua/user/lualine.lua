local M = {
	"nvim-lualine/lualine.nvim",
	dependencies = { "SmiteshP/nvim-navic" },
}

local session = function()
	local ok, _ = pcall(require, "auto-session")
	if ok then
		return require("auto-session.lib").current_session_name
	end
	return function()
		return nil
	end
end

local clients_lsp = function()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if next(clients) == nil then
		return ""
	end

	local c = {}
	for _, client in pairs(clients) do
		if not (client.name == "null-ls") then
			table.insert(c, client.name)
		end
	end
	return "\u{f085}  " .. table.concat(c, "|")
end

function M.config()
	local sl_hl = vim.api.nvim_get_hl_by_name("StatusLine", true)
	vim.api.nvim_set_hl(0, "Copilot", { fg = "#6CC644", bg = sl_hl.background })
	local icons = require("user.lspicons")
	local diff = {
		"diff",
		colored = true,
		symbols = { added = icons.git.LineAdded, modified = icons.git.LineModified, removed = icons.git.LineRemoved },
	}

	local copilot = function()
		local buf_clients = vim.lsp.active_clients({ bufnr = 0 })
		if #buf_clients == 0 then
			return "LSP Inactive"
		end

		local buf_client_names = {}
		local copilot_active = false

		for _, client in pairs(buf_clients) do
			if client.name ~= "null-ls" and client.name ~= "copilot" then
				table.insert(buf_client_names, client.name)
			end
			if client.name == "copilot" then
				copilot_active = true
			end
		end

		if copilot_active then
			return "%#Copilot#" .. icons.git.Octoface .. "%*"
		end
		return ""
	end

	local navic = require("nvim-navic")
	local git_blame = require("gitblame")
	local arrow = require("arrow.statusline")
	require("lualine").setup({
		options = {
			theme = "auto",
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			ignore_focus = { "NvimTree", "noice", "qf" },
			globalstatus = true,
			globalwinbar = true,
			disabled_filetypes = {
				"help",
				"qf",
				"nofile",
				"NvimTree",
				"terminal",
				"fugitiveblame",
				"fugitive",
				"fzf",
				"lazy",
				"mason",
				"trouble",
			},
		},
		sections = {
			lualine_a = {
				"mode",
				{
					function()
						return require("arrow.statusline").text_for_statusline_with_icons()
					end,
					cond = function()
						return require("arrow.statusline").is_on_arrow_file() ~= nil
					end,
				},
				{
					function()
						local rec = vim.fn.reg_recording()
						if rec == "" then
							return ""
						else
							return "Recording @" .. rec
						end
					end,
				},
			},
			lualine_b = { { "branch", icon = icons.git.Branch }, diff },
			lualine_c = {},
			lualine_x = {
				{ git_blame.get_current_blame_text, cond = git_blame.is_blame_text_available },
				"diagnostics",
				clients_lsp,
				copilot,
			},
			lualine_y = {
				{
					"fileformat",
					icons_enabled = true,
					symbols = {
						unix = icons.misc.Unix,
						dos = icons.misc.Dos,
						mac = icons.misc.Mac,
					},
				},
				"filetype",
				{
					arrow.text_for_statusline_with_icons(),
					--cond = true, -- arrow.is_on_arrow_file(),
				},
			},
			lualine_z = { "progress", session() },
		},
		inactive_sections = {
			lualine_a = {},
			lualine_b = { "filename" },
			lualine_x = { "filetype" },
		},
		extensions = { "quickfix", "man", "fugitive", "fzf", "lazy", "mason" },
		disabled_filetypes = {
			statusline = { "NvimTree", "terminal", "glow" },
			winbar = { "NvimTree", "terminal", "glow" },
		},

		winbar = {
			lualine_a = {
				{
					function()
						return navic.get_location()
					end,
					cond = function()
						return navic.is_available()
					end,
					color = "WarningMsg",
				},
			},
		},
		inactive_winbar = {},
	})
end

return M
