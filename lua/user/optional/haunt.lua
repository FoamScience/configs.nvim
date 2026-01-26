local M = {
    "TheNoeTrevino/haunt.nvim",
    event = "VeryLazy",
}

M.config = function ()
    require("haunt").setup({})
end

return M
