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
    require("gitblame").setup({
        display_virtual_text = true,
        message_template = "|| <author> • <date>",
        date_format = "%r",
        virtual_text_column = 80,
        highlight_group = "@lsp.type.comment",
        set_extmark_options = {
            hl_mode = "combine",
        },
        message_when_not_committed = "|| Oh! Plz commit me!",
        ignored_filetypes = { "python" },
    })
end

return M
