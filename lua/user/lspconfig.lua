local M = {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile", "LspAttach" },
    cmd = { "LspInfo", "LspInstall", "LspUninstall" },
    dependencies = {
        {
            "folke/neodev.nvim",
            "williamboman/mason.nvim",
            "p00f/clangd_extensions.nvim",
            "rachartier/tiny-inline-diagnostic.nvim",
        },
    },
}

local function lsp_keymaps(bufnr)
    local opts = { noremap = true, silent = true }
    local keymap = vim.api.nvim_buf_set_keymap
    keymap(bufnr, "n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
    keymap(bufnr, "n", "gI", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
    keymap(bufnr, "n", "gl", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
end

M.on_attach = function(client, bufnr)
    local status_ok, clangd_ext = pcall(require, "clangd_extensions")
    if client.name == "clangd" and status_ok then
        clangd_ext.setup({
            inlay_hints = {
                inline = vim.fn.has("nvim-0.10") == 1,
                only_current_line = true,
                highlight = "LspInlayHint",
            },
        })
        require("clangd_extensions.inlay_hints").setup_autocmd()
        require("clangd_extensions.inlay_hints").set_inlay_hints()
    end
    lsp_keymaps(bufnr)
end

function M.common_capabilities()
    local status_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
    if status_ok then
        return cmp_nvim_lsp.default_capabilities()
    end

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true
    capabilities.textDocument.completion.completionItem.resolveSupport = {
        properties = {
            "documentation",
            "detail",
            "additionalTextEdits",
        },
    }
    capabilities.textDocument.codeLens = { dynamicRegistration = false }

    return capabilities
end

function M.config()
    local lspconfig = require("lspconfig")
    local util = require("lspconfig.util")
    local icons = require("user.lspicons")

    local servers = {
        "clangd",
        "lua_ls",
        "cssls",
        "html",
        "ts_ls",
        "astro",
        "pyright",
        "bashls",
        "jsonls",
        "yamlls",
        "glsl_analyzer",
        "foam_ls",
        "rust_analyzer",
        "marksman",
    }

    local default_diagnostic_config = {
        signs = {
            active = true,
            values = {
                { name = "DiagnosticSignError", text = icons.diagnostics.Error },
                { name = "DiagnosticSignWarn",  text = icons.diagnostics.Warning },
                { name = "DiagnosticSignHint",  text = icons.diagnostics.Hint },
                { name = "DiagnosticSignInfo",  text = icons.diagnostics.Information },
            },
        },
        virtual_text = false,
        update_in_insert = false,
        underline = true,
        severity_sort = true,
        float = {
            focusable = true,
            style = "minimal",
            border = "rounded",
            source = "always",
            header = "",
            prefix = "",
        },
    }

    vim.diagnostic.config(default_diagnostic_config)
    require("tiny-inline-diagnostic").setup()

    for _, sign in ipairs(vim.tbl_get(vim.diagnostic.config(), "signs", "values") or {}) do
        vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = sign.name })
    end

    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
    require("lspconfig.ui.windows").default_options.border = "rounded"

    for _, server in pairs(servers) do
        local opts = {
            on_attach = M.on_attach,
            capabilities = M.common_capabilities(),
            handlers = vim.lsp.handlers,
        }

        local require_ok, settings = pcall(require, "user.lspsettings." .. server)
        if require_ok then
            opts = vim.tbl_deep_extend("force", settings, opts)
        end

        if server == "lua_ls" then
            require("neodev").setup({})
        end

        if server == "clangd" then
            opts.cmd = { "clangd", "--offset-encoding=utf-16", "--all-scopes-completion",
                "--clang-tidy", "--malloc-trim", "--function-arg-placeholders", "--enable-config" }
            opts.root_dir = util.root_pattern("compile_commands.json")
                or util.root_pattern(".git", "Make")
        end

        lspconfig[server].setup(opts)
    end
end

return M
