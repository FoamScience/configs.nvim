local M = {
	"VidocqH/lsp-lens.nvim",
	event = "VeryLazy",
    ft = {
        'cpp',
        'lua',
        'foam',
    },
}

function M.config()
	require("lsp-lens").setup {}
end

return M
