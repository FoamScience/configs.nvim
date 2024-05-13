local M = {
	"sourcegraph/sg.nvim",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
	event = { "LspAttach", "VeryLazy" },
}

function M.config()
	require("sg").setup{}
end

return M
