local M = {
	"hedyhli/outline.nvim",
	lazy = true,
	cmd = { "Outline", "OutlineOpen" },
}

function M.config()
	require("outline").setup({

	})
end

return M
