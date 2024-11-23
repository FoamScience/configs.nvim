local M = {
    "NMAC427/guess-indent.nvim",
    lazy = false,
}

M.config = function()
    require('guess-indent').setup {
        auto_cmd = true,
        override_editorconfig = false,
    }
end

return M
