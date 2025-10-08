local M = {
	"otavioschwanck/arrow.nvim",
	event = "VeryLazy",
}

function M.config()
    require("arrow").setup({
        show_icons = true,
        leader_key = ",",
        separate_by_branch = true,
        always_show_path = true,
        hide_buffer_handbook = true,
        save_key = "git_root",
    })
end

return M
