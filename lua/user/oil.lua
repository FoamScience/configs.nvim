local M = {
    "stevearc/oil.nvim",
    lazy = false, -- must load at startup so `nvim <folder>` opens oil
}

function M.config()
    require("oil").setup({
        default_file_explorer = true, -- oil takes over `nvim <folder>` (disables netrw)
    })
    vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
end

return M
