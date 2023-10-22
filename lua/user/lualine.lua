local M = {
	"nvim-lualine/lualine.nvim",
    dependencies = { "SmiteshP/nvim-navic", },
}

function M.config()
	local sl_hl = vim.api.nvim_get_hl_by_name("StatusLine", true)
	vim.api.nvim_set_hl(0, "Copilot", { fg = "#6CC644", bg = sl_hl.background })
	local icons = require "user.lspicons"
	local diff = {
		"diff",
		colored = true,
		symbols = { added = icons.git.LineAdded, modified = icons.git.LineModified, removed = icons.git.LineRemoved },
	}

	local copilot = function()
		local buf_clients = vim.lsp.get_active_clients { bufnr = 0 }
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
    local icons = require("user.lspicons")
	require("lualine").setup {
		options = {
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			ignore_focus = { "NvimTree" },
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { {"branch", icon =""}, },
			lualine_c = { diff },
			lualine_x = { "diagnostics", copilot },
			lualine_y = { "filetype" },
			lualine_z = { "progress" },
		},
		extensions = { "quickfix", "man", "fugitive" },
		winbar = {
			lualine_a = {
                {
                    "buffers",
                    hide_filename_extension = true,
                    symbols = {
                        modified = " " .. icons.ui.Pencil,
                        alternate_file = icons.ui.Files,
                        directory = icons.ui.Folder,
                    }
                },
            },
			lualine_b = {
                {
                    function()
				        return navic.get_location()
				    end,
				    cond = function()
				        return navic.is_available()
				    end,
                    color = 'WarningMsg'
                },
            },
			lualine_c = {},
			lualine_x = {},
			lualine_y = {},
			lualine_z = {
            },
		},
}
end

return M
