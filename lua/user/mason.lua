local M = {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
        "williamboman/mason.nvim",
        "nvim-lua/plenary.nvim",
    },
}

M.servers = {
    "lua_ls",
    "cssls",
    "html",
    "pyright",
    "bashls",
    "jsonls",
    "yamlls",
    "foam_ls",
    "marksman",
}

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
    })
end

return M
