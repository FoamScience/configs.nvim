local M = {
	"f-person/git-blame.nvim",
	event = "VeryLazy",
    ft = {
        'cpp',
        'lua',
        'foam',
    },
}

function M.config()
	require("gitblame").setup {}
end

return M
