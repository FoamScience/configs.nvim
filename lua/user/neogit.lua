local M = {
	"neogitorg/neogit",
    --event = {"BufReadPre", "BufNewFile"},
	cmd = { "Neogit", "NeogitCommit" },
    dependencies = {
        "nvim-lua/plenary.nvim",
        "sindrets/diffview.nvim",
    },
}

function M.config()
	local icons = require "user.lspicons"

	require("neogit").setup {
		disable_signs = false,
		disable_context_highlighting = false,
		disable_commit_confirmation = true,
		disable_insert_on_commit = "auto",
		auto_refresh = true,
		disable_builtin_notifications = false,
		use_magit_keybindings = false,
		kind = "floating",
		commit_popup = {
			kind = "vsplit",
		},
		popup = {
			kind = "vsplit",
		},
		signs = {
			section = { icons.ui.ChevronRight, icons.ui.ChevronShortDown },
			item = { icons.ui.ChevronRight, icons.ui.ChevronShortDown },
			hunk = { "", "" },
		},
		integrations = {
			diffview = true,
		},
	}
end

return M
