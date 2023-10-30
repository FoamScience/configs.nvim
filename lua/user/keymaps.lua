local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

keymap("n", "<C-Space>", "<cmd>WhichKey \\<space><cr>", opts)
keymap("n", "<C-i>", "<C-i>", opts)

-- hopping
keymap("n", "s", "<cmd>HopWord<cr>", opts)
keymap("n", "S", "<cmd>HopChar2<cr>", opts)

-- Buffer hopping
keymap("n", "<Tab>", "<cmd>bn<cr>", opts)
keymap("n", "<S-Tab>", "<cmd>bp<cr>", opts)
