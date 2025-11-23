local M = {
    "NMAC427/guess-indent.nvim",
    event = { "BufReadPost", "BufNewFile" },
}

M.config = function()
    require('guess-indent').setup {
        auto_cmd = true,
        override_editorconfig = false,
    }
end

return M
