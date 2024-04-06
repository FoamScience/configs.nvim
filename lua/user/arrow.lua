local M = {
	"otavioschwanck/arrow.nvim",
	event = "VeryLazy",
}

function M.config()
    local arrow = require("arrow")
    arrow.setup {
        show_icons = true,
        leader_key = ",",
    }
end

return M
