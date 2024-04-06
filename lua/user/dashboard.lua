local M = {
    'nvimdev/dashboard-nvim',
    dependencies = { { 'nvim-tree/nvim-web-devicons' } },
    event = "VimEnter",
}
function M.config()
    local db = require("dashboard")
    db.setup {
        config = {
            theme = "hyper",
            header = { "", "Press <Space> to get started!", "This is a minimal config optimized for C++ and OpenFOAM", "" },
            week_header = {
                enable = false,
            },
            shortcut = {
                { desc = "󰊳 Update", group = "@property", action = "Lazy update", key = "u", },
                { desc = " Keymaps", group = "@property", action = "Telescope keymaps", key = "k", },
            },
        },
    }
end

return M
