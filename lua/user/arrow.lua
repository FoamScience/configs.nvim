local M = {
	"otavioschwanck/arrow.nvim",
	event = "VeryLazy",
}

function M.config()
    local arrow = require("arrow")
    arrow.setup {
        show_icons = true,
        leader_key = ",",
        separate_by_branch =false,
        always_show_path = true,
        save_key="cwd",
    }
end

return M
