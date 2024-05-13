local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = LAZY_PLUGIN_SPEC,
	git = {
		log = { "-10" },
	},
	install = {
		colorscheme = { "primer_dark", "habamax" },
	},
	ui = {
		border = "rounded",
		title = "Lazy Plugins",
	},
	change_detection = {
		enabled = true,
		notify = false,
	},
})
