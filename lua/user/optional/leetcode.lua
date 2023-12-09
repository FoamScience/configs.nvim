local M = {
	"kawre/leetcode.nvim",
    build = ":TSUpdate html",
	event = "BufEnter leetcode.nvim",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        "nvim-treesitter/nvim-treesitter",
        "rcarriga/nvim-notify",
        "nvim-tree/nvim-web-devicons",
    },
}

function M.config()
    require("leetcode").setup({
        logging = false,
    })
end

return M
