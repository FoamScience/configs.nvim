local M = {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
}

M.config = function()
    require("img-clip").setup{}
end

return M
