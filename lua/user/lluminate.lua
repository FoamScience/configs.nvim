local M = {
    "k2589/LLuMinate.nvim",
    event = "VeryLazy",
    cmd = "EnrichContext"
}

M.config = function()
    require('lluminate').setup({
        include_definition = false,
        diagnostic_levels = {
            "Error"
        }
    })
end

return M
