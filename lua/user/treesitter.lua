local ensure_installed = {
	"lua", "vim", "vimdoc", "regex",
	"markdown", "markdown_inline", "html", "typst", "yaml", "latex", "norg",
	"bash",
	"python",
	"foam", "cpp", "c",
	"rust", "glsl",
	"xonsh",
}
local M = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	event = { "BufReadPost", "BufNewFile" },
	cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
	build = ":TSUpdate",
	opts = {
		ensure_installed = ensure_installed,
	},
	--dependencies = {
	--	"nvim-treesitter/nvim-treesitter-textobjects",
	--	branch = "main"
	--}
}
function M.config()
	require("nvim-treesitter").setup({
		install_dir = vim.fn.stdpath('data') .. '/site'
	})
	vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
	vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	require("nvim-treesitter").get_installed(true)
	-- Defer treesitter start to avoid blocking FileType event
	vim.api.nvim_create_autocmd('FileType', {
		pattern = ensure_installed,
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			vim.defer_fn(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					local start_ok = pcall(function()
						vim.treesitter.start(bufnr)
					end)
					if not start_ok then
						vim.notify("Treesitter parser didn't start correctly for this buffer", vim.log.levels.WARN)
					end
				end
			end, 1)
		end,
	})
	-- Defer parser installation to avoid blocking startup
	vim.schedule(function()
		require("nvim-treesitter").install(ensure_installed)
	end)
end

return M
