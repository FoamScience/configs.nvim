local M = {
    "mistweaverco/diffconflicts.nvim",
    event = { "BufReadPre", "BufNewFile" },
}
M.config = function()
    require("diffconflicts").setup {}
end

return M
