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
	-- Lock plugin versions using lazy-lock.json
	lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
	git = {
		log = { "-10" },
	},
	install = {
		missing = true, -- install missing plugins on startup
		colorscheme = { "primer_dark", "habamax" },
	},
	checker = {
		enabled = false, -- disable automatic update checks
	},
	ui = {
		border = "rounded",
		title = "Lazy Plugins",
	},
	change_detection = {
		enabled = true,
		notify = false,
	},
	performance = {
		reset_packpath = true,
	},
})
