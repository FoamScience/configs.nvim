local M = {
	"nvim-tree/nvim-web-devicons",
	event = "VeryLazy",
}
function M.config()
	local devicons = require "nvim-web-devicons"
	devicons.set_icon {
		astro = {
			--  󱓟 
			icon = " ",
			color = "#FF7E33",
			name = "astro",
		},
	}
end

-- Compute average of a list of numbers

return M
