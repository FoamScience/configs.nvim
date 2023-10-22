local M = {
	"williamboman/mason-lspconfig.nvim",
	dependencies = {
		"williamboman/mason.nvim",
		"nvim-lua/plenary.nvim",
	},
}

M.servers = {
	"lua_ls",
	"cssls",
	"html",
	"tsserver",
	"pyright",
	"bashls",
	"jsonls",
	"yamlls",
	"tailwindcss",
	"foam_ls",
	"clangd"
}

function M.config()
	require("mason").setup {
		ui = {
			border = "rounded",
		},
	}
	require("mason-lspconfig").setup {
		ensure_installed = M.servers,
	}
end

return M
