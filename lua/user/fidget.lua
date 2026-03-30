local M = {
    "j-hui/fidget.nvim",
    event = "VeryLazy",
}

M.config = function ()
    require('fidget').setup()
end

return M
