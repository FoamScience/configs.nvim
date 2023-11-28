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
	require("gitblame").setup ({
        display_virtual_text = false,
        message_when_not_committed = "Oh! Plz commit me!",
        ignored_filetypes = { "python" },
    })
end

return M
