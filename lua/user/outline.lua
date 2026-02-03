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
			goto_location = {'<Cr>', 'go'},
			goto_and_close = '<S-Cr>',
			peek_location = {'P'},
			restore_location = '<C-g>',
			hover_symbol = 'K',
			toggle_preview = 'p',
			rename_symbol = 'r',
			code_actions = 'a',
			fold_toggle = 'f',
			fold_toggle_all = 'F',
			down_and_jump = '<C-j>',
			up_and_jump = '<C-k>',
		}
	})
end

return M
