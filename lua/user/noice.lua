local M = {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
        "MunifTanjim/nui.nvim",
    },
}

function M.config()
    require("noice").setup({
        cmdline = { enabled = true, view = "cmdline_popup" },
        messages = { enabled = false },
        popupmenu = { enabled = false },
        notify = { enabled = false },
        lsp = {
            hover = { enabled = false },
            signature = { enabled = false },
            message = { enabled = false },
            progress = { enabled = false },
        },
        views = { cmdline_popup = { position = { row = 1, col = "50%" } } },
    })
end

return M
