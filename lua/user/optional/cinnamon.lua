local M = {
	"declancm/cinnamon.nvim",
	event = "VeryLazy",
}

function M.config()
    require("cinnamon").setup({
        default_keymaps = true,
        extra_keymaps = true,
        extended_keymaps = true,
        default_delay = 4,
    })
end

return M
