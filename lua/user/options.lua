vim.opt.backup = false -- no backups
vim.opt.writebackup = false -- absolutely no backups
vim.opt.swapfile = false -- no swapfiles

vim.opt.clipboard = "unnamedplus" -- allows neovim to access the system clipboard

vim.opt.cmdheight = 2 -- more space in the neovim command line for displaying messages
vim.opt.completeopt = { "menuone", "noselect" } -- cmp

vim.opt.conceallevel = 2 -- conceal is cool
vim.opt.hlsearch = false -- no highlight after search
vim.opt.ignorecase = true -- ignore case
vim.opt.showcmd = false

vim.opt.mouse = "" -- no mouse

vim.opt.showmode = false -- no annoying __ INSERT __
vim.opt.showtabline = 1 -- always show tabs
vim.opt.expandtab = true -- tabs to spaces
vim.opt.shiftwidth = 4 -- the number of spaces inserted for each indentation
vim.opt.tabstop = 4 -- insert 4 spaces for a tab

vim.opt.smartcase = true -- smart case
vim.opt.smartindent = true -- smart indenting
vim.opt.termguicolors = true -- set term gui colors

vim.opt.timeoutlen = 1000 -- time to wait for a mapped sequence to complete
vim.opt.updatetime = 100 -- faster completion (4000ms default)

vim.opt.number = true -- set numbered lines
vim.opt.relativenumber = true -- set relative numbered lines
vim.opt.numberwidth = 4 -- number column width to 4
vim.opt.signcolumn = "yes" -- show the sign column

vim.opt.undofile = true -- enable persistent undo
vim.opt.cursorline = true -- highlight the current line

vim.opt.wrap = false -- display lines as one long line

vim.opt.scrolloff = 0
vim.opt.sidescrolloff = 8

vim.opt.fillchars = vim.opt.fillchars + "eob: "
vim.opt.fillchars:append {
	stl = " ",
}

vim.opt.laststatus = 3

vim.opt.shortmess:append "c"

vim.cmd "set whichwrap+=<,>,[,],h,l"
vim.cmd [[set iskeyword+=-]]
