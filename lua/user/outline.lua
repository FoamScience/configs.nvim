local M = {
	"hedyhli/outline.nvim",
	lazy = true,
	cmd = { "Outline", "OutlineOpen" },
}

function M.config()
	require("outline").setup({
		keymaps = {
			show_help = '?',
			close = {'<ESC>', 'q'},
			goto_location = '<S-Cr>',
			goto_and_close = '<Cr>',
			peek_location = {'P'},
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
