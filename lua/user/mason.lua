local M = {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
        "williamboman/mason.nvim",
        "nvim-lua/plenary.nvim",
        "neovim/nvim-lspconfig"
    },
}

M.servers = require("user.lspconfig").servers or {}

local arch = vim.loop.os_uname().machine
if not arch == "aarch64" then
    table.insert(M.servers, "clangd")
end

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
