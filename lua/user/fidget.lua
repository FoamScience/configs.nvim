local M = {
    "j-hui/fidget.nvim",
    event = "VeryLazy",
}

M.config = function ()
    require('fidget').setup({
        notification = {
            window = {
                avoid = { "NvimTree" },
            },
        },
    })
end

return M
