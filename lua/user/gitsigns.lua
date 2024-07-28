local M = {
	"lewis6991/gitsigns.nvim",
    event = {"BufReadPre", "BufNewFile"},
}
M.config = function()
	local icons = require("user.lspicons")

	require("gitsigns").setup({
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		attach_to_untracked = true,
		current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
		update_debounce = 200,
		max_file_length = 40000,
		preview_config = {
			border = "rounded",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
	})
end

return M
