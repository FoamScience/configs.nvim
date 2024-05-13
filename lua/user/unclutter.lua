local M = {
	"pablopunk/unclutter.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"nvim-telescope/telescope.nvim",
	},
}

function M.config()
	require("unclutter").setup({})
end

return M
