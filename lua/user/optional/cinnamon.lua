local M = {
	"declancm/cinnamon.nvim",
	event = "VeryLazy",
}

function M.config()
    require("cinnamon").setup({
    })
end

return M
