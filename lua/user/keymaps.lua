local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

whichkey_ok, _ = pcall(require, "whichkey")
if whichkey_ok then
    keymap("n", "<C-Space>", "<cmd>WhichKey \\<space><cr>", opts)
end
keymap("n", "<C-i>", "<C-i>", opts)

-- Buffer hopping
keymap("n", "<Tab>", "<cmd>bn<cr>", opts)
keymap("n", "<S-Tab>", "<cmd>bp<cr>", opts)
