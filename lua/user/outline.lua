local M = {
	"FoamScience/outline.nvim",
	branch = "splitkeep",
	lazy = true,
	cmd = { "Outline", "OutlineOpen" },
}

function M.config()
	require("outline").setup({
		outline_window = {
			auto_jump = false,
			position = "left",
			focus_on_open = true,
		},
		outline_items = {
			show_symbol_lineno = true,
		},
		keymaps = {
			show_help = '?',
			close = {'<ESC>', 'q'},
			goto_location = '<Cr>',
			goto_and_close = '<S-Cr>',
			peek_location = 'o',
			restore_location = '<C-g>',
			hover_symbol = 'K',
			toggle_preview = 'p',
			rename_symbol = 'r',
			code_actions = 'a',
			fold_toggle = 'za',
			fold_toggle_all = 'zA',
			down_and_jump = '<C-j>',
			up_and_jump = '<C-k>',
		}
	})
end

return M
