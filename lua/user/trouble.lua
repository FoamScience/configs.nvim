-- trouble.nvim — pretty list for diagnostics / symbols / LSP / qf. The user
-- already references a "trouble" sidebar filetype in mini-statusline; this wires
-- the actual plugin. All keymaps live under <leader>x (group in whichkey.lua).
return {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
        focus = false,
        modes = {
            symbols = { win = { position = "right" } },
        },
    },
    keys = {
        { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                        desc = "Diagnostics" },
        { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",           desc = "Buffer diagnostics" },
        { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>",                desc = "Symbols" },
        { "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP defs / refs" },
        { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                            desc = "Location list" },
        { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                             desc = "Quickfix list" },
        { "<leader>xt", "<cmd>Trouble todo toggle<cr>",                               desc = "Todo (todo-comments)" },
    },
}
