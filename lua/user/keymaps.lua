local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }
local function is_floating_window()
    return vim.api.nvim_win_get_config(0).relative ~= ""
end

keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local whichkey_ok, _ = pcall(require, "whichkey")
if whichkey_ok then
    keymap("n", "<C-Space>", "<cmd>WhichKey \\<space><cr>", opts)
end
keymap("n", "<C-i>", "<C-i>", opts)
keymap("t", "<Esc>", [[<C-\><C-n>]], { noremap = true })

-- Buffer hopping
local disabled_tab_hopping = {
    help = true,
    qf = true,
    nofile = true,
    fugitiveblame = true,
    fugitive = true,
    NeogitStatus = true,
    fzf = true,
    lazy = true,
    mason = true,
}
keymap("n", "<Tab>", function()
    if disabled_tab_hopping[vim.bo.filetype]
        or is_floating_window()
    then
        return
    end
    if not (vim.fn.winlayout()[1] == "leaf") then
        vim.cmd('wincmd w')
    else
        vim.cmd("bn")
    end
end, opts)
keymap("n", "<S-Tab>", function()
    if disabled_tab_hopping[vim.bo.filetype]
        or is_floating_window()
    then
        return
    end
    if not (vim.fn.winlayout()[1] == "leaf") then
        vim.cmd('wincmd x')
    else
        vim.cmd("bp")
    end
end, opts)
