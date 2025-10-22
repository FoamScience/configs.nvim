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

    -- redirect :marks and :registers to snacks picker
    vim.cmd([[
        cnoreabbrev <expr> marks getcmdtype() == ':' && getcmdline() == 'marks' ? 'lua require("snacks").picker.marks()' : 'marks'
        cnoreabbrev <expr> registers getcmdtype() == ':' && getcmdline() == 'registers' ? 'lua require("snacks").picker.registers()' : 'registers'
        cnoreabbrev <expr> reg getcmdtype() == ':' && getcmdline() == 'reg' ? 'lua require("snacks").picker.registers()' : 'reg'
    ]])
end

return M
