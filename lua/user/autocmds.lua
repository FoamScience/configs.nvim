vim.api.nvim_create_autocmd({ "CmdWinEnter" }, {
    desc = "Huh?",
	callback = function()
		vim.cmd "quit"
	end,
})

vim.api.nvim_create_autocmd({ "TextYankPost" }, {
    desc = "Highight when yanking",
	callback = function()
		vim.highlight.on_yank { higroup = "@comment.warning", timeout = 40 }
	end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
    desc = "Set wrap and spell for some file types",
	pattern = { "gitcommit", "markdown", "latex", "tex", "NeogitCommitMessage" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end,
})


--vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
--    desc = "fix cmp completion in visual mode",
--	callback = function()
--        require('cmp').setup.buffer({ enabled = vim.api.nvim_get_mode().mode == 'c' })
--	end,
--})
