local M = {
    "ChmaraX/herdr-nvim",
    event = "VeryLazy",
}

-- the herdr daemon also calls setup() on VimEnter; keymaps = false keeps the
-- second call from warning about its own maps
M.config = function()
    local herdr = require("herdr-nvim")
    herdr.setup({ keymaps = false })
    local map = vim.keymap.set
    map("n", "<leader>ac", herdr.comment_line, { desc = "herdr-nvim: comment line" })
    map("x", "<leader>ac", herdr.comment_selection, { desc = "herdr-nvim: comment selection" })
    map("n", "<leader>al", herdr.list_comments, { desc = "herdr-nvim: list comments" })
    map("n", "<leader>as", function()
        herdr.send_all({ submit = false })
    end, { desc = "herdr-nvim: paste comments to agent" })
    map("n", "<leader>aS", function()
        herdr.send_all({ submit = true })
    end, { desc = "herdr-nvim: send comments to agent" })
    map("n", "<leader>ai", herdr.ref_line, { desc = "herdr-nvim: reference line at agent cursor" })
    map("x", "<leader>ai", herdr.ref_selection, { desc = "herdr-nvim: reference selection at agent cursor" })
end

return M
