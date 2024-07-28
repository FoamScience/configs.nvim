local M = {
	"theKnightsOfRohan/csvlens.nvim",
	dependencies = {
		"akinsho/toggleterm.nvim",
	},
}

function M.config()
	require("csvlens").setup({})
end

return M
