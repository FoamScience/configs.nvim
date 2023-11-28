local M = {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
}

function M.config()
    require('Comment').setup({
        padding = true,
        toggler = {
            line = "gcc",
            block = "gbc",
        },
    })
end

return M
