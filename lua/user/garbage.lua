local M = {
	"zeioth/garbage-day.nvim",
    dependencies = "neovim/nvim-lspconfig",
	event = "LspAttach",
}
function M.config()
	local garbage = require "garbage-day"
    garbage.setup {
        aggressive_mode = true,
    }
end

return M
