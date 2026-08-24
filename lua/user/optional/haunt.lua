local M = {
    "TheNoeTrevino/haunt.nvim",
    keys = { "<leader>kk", "<leader>kd", "<leader>kc", "<leader>kl", "<leader>kt", "<leader>kT" },
}

M.config = function()
    require("haunt").setup({})
end

return M
