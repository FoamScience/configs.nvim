local M = {
    "folke/snacks.nvim",
    priority = 1000,
}

M.config = function()
    require("snacks").setup({
        styles = {
            snacks_image = {
                relative = "editor",
                col = -1,
                row = 2,
            },
        },
        animate = {},
        indent = {
            enabled = true,
        },
        input = {
            border = "rounded",
        },
        image = {
            enabled = true,
            doc = {
                inline = false,
                float = true,
            },
            convert = {
                notify = false,
            }
        },
        picker = {
            enabled = true,
        },
    })
end

return M
