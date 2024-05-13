local M = {
	"karb94/neoscroll.nvim",
	event = "VeryLazy",
}

function M.config()
    require("neoscroll").setup{}
end

return M
