local M = {
    "mason-org/mason-lspconfig.nvim",
    lazy = true,
}

local ensure_installed = vim.tbl_deep_extend('keep',
    require("user.lspconfig").servers,
    require("user.lspconfig").flat_formatters) or {}

function M.config()
    require("mason-lspconfig").setup({
        ensure_installed = ensure_installed,
        automatic_enable = false,
        automatic_installation = true,
        ui = {
            border = "rounded",
        },
    })
end

return M
