local M = {
    "williamboman/mason-lspconfig.nvim",
    lazy = true,
    dependencies = {
        "williamboman/mason.nvim",
        "nvim-lua/plenary.nvim",
        "neovim/nvim-lspconfig"
    },
}

M.servers = require("user.lspconfig").servers or {}

function M.config()
    require("mason").setup({
        ui = {
            border = "rounded",
        },
    })
    require("mason-lspconfig").setup({
        ensure_installed = M.servers,
        automatic_enable = false,
        automatic_installation = true,
    })
end

return M
