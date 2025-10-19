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
            layout = {
                width = 0.9,
                --reverse = true,
                --layout = {
                --    box = "horizontal",
                --    backdrop = false,
                --    width = 0.9,
                --    height = 0.9,
                --    border = "none",
                --    {
                --        box = "vertical",
                --        {
                --            win = "list",
                --            title = " Results ",
                --            title_pos = "center",
                --            border = "rounded"
                --        },
                --        {
                --            win = "input",
                --            height = 1,
                --            border = "rounded",
                --            title = "{title} {live} {flags}",
                --            title_pos = "center"
                --        },
                --    },
                --    {
                --        win = "preview",
                --        title = "{preview:Preview}",
                --        width = 0.50,
                --        border = "rounded",
                --        title_pos = "center",
                --    },
                --},
            }
        }
    })
end

return M
