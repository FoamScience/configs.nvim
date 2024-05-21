local M = {
    "kevinhwang91/nvim-bqf",
    ft = 'qf',
}

M.config = function()
    require('bqf').setup({
        auto_enable = true,
        auto_resize_height = true,
        preview = {
            winblend = 0,
            winheight = 10,
        },
    })
end

return M
