local M = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
}
function M.config()

	local ensure_installed = {
		"lua", "vim", "vimdoc",
        "latex",
        "regex",
		"markdown", "markdown_inline",
		"bash",
		"python",
		"foam", "cpp", "c",
		"rust", "glsl",
	}
	vim.api.nvim_create_autocmd('FileType', {
	  pattern = ensure_installed,
	  callback = function() vim.treesitter.start() end,
	})
	vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
	vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	require("nvim-treesitter").setup({
		install_dir = vim.fn.stdpath('data') .. '/site'
	})
	require'nvim-treesitter'.install(ensure_installed)
end

return M
