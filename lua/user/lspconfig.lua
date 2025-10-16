local icons = require("user.lspicons")

local M = {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "LspInfo", "LspInstall", "LspUninstall" },
    dependencies = {
        {
            "mason-org/mason.nvim",
            config = function()
                require("mason").setup({
                    ui = {
                        icons = {
                            package_installed = "✓",
                            package_pending = "➜",
                            package_uninstalled = "✗"
                        }
                    }
                })
            end
        },
        "folke/lazydev.nvim",
        "rachartier/tiny-inline-diagnostic.nvim",
        "mason-org/mason-lspconfig.nvim"
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
    if client.server_capabilities.inlayHintProvider then
        vim.g.inlay_hints_visible = false
        --vim.lsp.inlay_hint.enable()
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

M.servers = {
    "clangd",
    "lua_ls",
    "cssls",
    "html",
    "astro",
    "pyright",
    "bashls",
    "jsonls",
    "yamlls",
    "glsl_analyzer",
    "foam_ls",
    "tinymist",
    "rust_analyzer",
    "marksman",
}

M.formatter_map = {
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    json = { "jq" }
}
local unique_formatter = {}
for _, fmt_list in pairs(M.formatter_map) do
    for _, v in pairs(fmt_list) do
        if type(v) == "string" then
            unique_formatter[v] = true
        end
    end
end
M.flat_formatters = {}
for name in pairs(unique_formatter) do
    table.insert(M.flat_formatters, name)
end

local ensure_installed = vim.tbl_deep_extend('keep', M.servers, M.flat_formatters) or {}

M.config = vim.schedule_wrap(function()
    require("mason-lspconfig").setup({
        ensure_installed = ensure_installed,
        automatic_enable = true,
        automatic_installation = false,
        ui = {
            border = "rounded",
        },
    })
    local util = require("lspconfig.util")

    local default_diagnostic_config = {
        signs = {
            text = {
                [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
                [vim.diagnostic.severity.WARN] = icons.diagnostics.Warning,
                [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
                [vim.diagnostic.severity.INFO] = icons.diagnostics.Information,
            },
            numhl = {
                [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
                [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
                [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
                [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
            },
        },
        virtual_text = false,
        update_in_insert = false,
        underline = true,
        severity_sort = true,
        float = {
            focusable = true,
            border = "rounded",
            source = "if_many",
            header = "",
            prefix = "",
        },
    }

    vim.diagnostic.config(default_diagnostic_config)
    require("tiny-inline-diagnostic").setup()

    --for _, sign in ipairs(vim.tbl_get(vim.diagnostic.config(), "signs", "values") or {}) do
    --    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = sign.name })
    --end

    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
    require("lspconfig.ui.windows").default_options.border = "rounded"

    for _, server in pairs(M.servers) do
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
            require("lazydev").setup({
                ft = "lua",
            })
        end

        if server == "clangd" then
            opts.cmd = {
                "clangd",
                "--offset-encoding=utf-16",
                "--all-scopes-completion",
                "--completion-style=bundled",
                "--clang-tidy",
                "--malloc-trim",
                "--function-arg-placeholders",
                "--header-insertion=iwyu",
                "--header-insertion-decorators",
                "--enable-config",
            }
            opts.filetypes = { "c", "cpp" }
            opts.root_dir = util.root_pattern("compile_commands.json", ".git", "Make")
        end

        if server == "pyright" then
            opts.cmd = { "pyright-langserver", "--stdio" }
            opts.root_dir = util.root_pattern("pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile",
                ".git")

            -- Start with system python, detect UV path after attach
            local python_path = vim.fn.exepath("python3") or vim.fn.exepath("python")

            opts.settings = {
                python = {
                    pythonPath = python_path,
                    analysis = {
                        autoSearchPaths = true,
                        useLibraryCodeForTypes = true,
                        diagnosticMode = "workspace",
                    }
                }
            }

            -- Defer UV python path detection to first attach
            local base_on_attach = opts.on_attach or M.on_attach
            opts.on_attach = function(client, bufnr)
                base_on_attach(client, bufnr)

                -- Only run once per session
                if not M._uv_python_path_detected then
                    M._uv_python_path_detected = true
                    vim.schedule(function()
                        if vim.fn.executable("uv") == 1 then
                            local handle = io.popen('uv run python -c "import sys; print(sys.executable)" 2>/dev/null')
                            if handle then
                                local result = handle:read("*a"):gsub("%s+", "")
                                handle:close()
                                if result ~= "" and vim.fn.filereadable(result) == 1 then
                                    client.config.settings.python.pythonPath = result
                                    client.notify("workspace/didChangeConfiguration",
                                        { settings = client.config.settings })
                                end
                            end
                        end
                    end)
                end
            end
        end

        vim.lsp.config(server, opts)
    end
end)

return M
