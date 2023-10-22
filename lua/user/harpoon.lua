local M = {
	"ThePrimeagen/harpoon",
	event = "VeryLazy",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
	},
}

function M.config()
	local keymap = vim.keymap.set
	local opts = { noremap = true, silent = true }

	keymap("n", "<S-TAB>", "<cmd>lua require('harpoon.mark').add_file()<cr>", opts)
	keymap("n", "<TAB>", "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>", opts)
	vim.api.nvim_create_autocmd({ "filetype" }, {
		pattern = "harpoon",
		callback = function()
			vim.cmd [[highlight link HarpoonBorder TelescopeBorder]]
			vim.cmd [[setlocal nonumber]]
		end,
	})
end

return M
