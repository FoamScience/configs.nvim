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

-- hopping
hop_ok, _ = pcall(require, "hop")
if hop_ok then
    keymap("n", "s", "<cmd>HopWord<cr>", opts)
    keymap("n", "S", "<cmd>HopChar2<cr>", opts)
end

-- Buffer hopping
keymap("n", "<Tab>", "<cmd>bn<cr>", opts)
keymap("n", "<S-Tab>", "<cmd>bp<cr>", opts)
