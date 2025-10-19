local M = {
    "rachartier/tiny-code-action.nvim",
    dependencies = {
        {"nvim-lua/plenary.nvim"},
    },
    event = "LspAttach",
}

function M.config()
    require("tiny-code-action").setup {
    }
end

return M
