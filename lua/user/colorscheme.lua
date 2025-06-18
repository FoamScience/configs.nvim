local M = {
    "uZer/pywal16.nvim",
    lazy = false,
    priority = 1000,
    enabled = function()
        -- fallback configured in colorscheme-fallback.lua
        return vim.fn.executable("wal") == 1
    end,
    name = "pywal16",
    init = function()
        vim.cmd.colorscheme "pywal16"
    end,
}

function M.config()
    require("pywal16").setup({})
end

return M
