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
    desc = "Set wrap for some file types",
	pattern = { "gitcommit", "markdown", "latex", "tex", "NeogitCommitMessage", "typst", "rmd" },
	callback = function()
		vim.opt_local.wrap = true
	end,
})


vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    desc = "Apptainer files as shell ft",
    pattern = "*.def",
    callback = function()
        vim.bo.ft = "bash"
    end,
})
