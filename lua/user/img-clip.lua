local M = {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    cond = function()
        return vim.env.SSH_CONNECTION == nil
    end,
}

M.config = function()
    require("img-clip").setup{}
end

return M
