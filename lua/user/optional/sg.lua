local M = {
    "sourcegraph/sg.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim"
    },
}

function M.config()
    require("sg").setup {}
end

return M
