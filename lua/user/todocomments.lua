local M = {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
}

function M.config()
    require("todo-comments").setup({
        keywords = {
            FIX  = { icon = " ", color = "info", alt = { "body", } },
            TODO = { icon = " ", color = "info", alt = { "todo", } },
            HACK = { icon = " ", color = "warning", alt = { "hack", } },
            WARN = { icon = " ", color = "warning", alt = { "warn", } },
            TEST = { icon = "⏲ ", color = "test", alt = { "test", } },
        },
        merge_keywords = false,
        search = {
            pattern = [[\b(@KEYWORDS):]], -- ripgrep regex, start with @, end with :
        },
    })
end

return M
