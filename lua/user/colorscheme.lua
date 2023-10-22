local M = {
	"catppuccin/nvim",
	lazy = false, -- load at startup cuz it's the main colorscheme
	priority = 1000, -- load it before anything else
}

function M.config()
	vim.cmd.colorscheme "catppuccin"
end

return M
