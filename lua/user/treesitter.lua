local ensure_installed = {
	"lua", "vim", "vimdoc", "regex",
	"markdown", "markdown_inline", "html", "typst", "yaml", "latex",
	"bash",
	"python",
	"foam", "cpp", "c",
	"rust", "glsl",
}
local M = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = vim.fn.argc(-1) == 0,
	event = "VeryLazy",
	cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
	build = ":TSUpdate",
	opts = {
		ensure_installed = ensure_installed,
	},
}
function M.config()
	require("nvim-treesitter").setup({
		install_dir = vim.fn.stdpath('data') .. '/site'
	})
	vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
	vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	require("nvim-treesitter").get_installed(true)
	vim.api.nvim_create_autocmd('FileType', {
		pattern = ensure_installed,
		callback = function()
			local start_ok = pcall(function()
				vim.treesitter.start()
			end)
			if not start_ok then
				vim.notify("Treesitter parser didn't start correctly for this buffer", vim.log.levels.WARN)
			end
		end,
	})
	--require("nvim-treesitter").install(ensure_installed):wait(300000)
end

return M
