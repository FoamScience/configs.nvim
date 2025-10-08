local icons = require("user.lspicons")

local M = {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "LspInfo", "LspInstall", "LspUninstall" },
    dependencies = {
        "folke/lazydev.nvim",
        "rachartier/tiny-inline-diagnostic.nvim",
        "williamboman/mason-lspconfig.nvim",
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

-- add stuff to servers_map, the rest is handled automatically
M.servers_map = {
    lua_ls = { "lua" },
    cssls = { "css", "scss", "less" },
    html = { "html" },
    astro = { "astro" },
    pyright = { "python" },
    bashls = { "sh", "bash", "zsh" },
    jsonls = { "json", "jsonc" },
    yamlls = { "yaml", "yml" },
    glsl_analyzer = { "glsl", "vert", "frag", "geom" },
    foam_ls = { "foam", "OpenFOAM" },
    tinymist = { "typst" },
    rust_analyzer = { "rust" },
    marksman = { "markdown" },
}
local arch = vim.loop.os_uname().machine
if arch ~= "aarch64" then
    M.servers_map["clangd"] = { "c", "cpp", "objc", "objcpp" }
end

M.servers = vim.tbl_keys(M.servers_map)
M.filetype_map = {}
for server, filetypes in pairs(M.servers_map) do
    for _, ft in ipairs(filetypes) do
        M.filetype_map[ft] = server
    end
end
M.served_filetypes = vim.tbl_keys(M.filetype_map)
M._setup_servers = {} -- Track which servers have been setup

function M.config()
    -- Load mason when LSP config loads
    require("user.mason").config()

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
        underline = function(_, buf_nr)
            return #vim.diagnostic.get(buf_nr) <= 10
        end,
        severity_sort = true,
        float = {
            focusable = true,
            border = "rounded",
            source = "if_many",
            header = "",
            prefix = "",
        },
    }

    vim.schedule(function()
        vim.diagnostic.config(default_diagnostic_config)
        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
        require("tiny-inline-diagnostic").setup()
        require("lspconfig.ui.windows").default_options.border = "rounded"
    end)

    local MAX_DIAGNOSTICS = 10
    local diags = vim.diagnostic.get(0)
    if #diags > MAX_DIAGNOSTICS then
        vim.diagnostic.hide(nil, 0)
    else
        vim.diagnostic.show(nil, 0)
    end

    -- Defer LSP start to reduce FileType event time
    vim.api.nvim_create_autocmd("FileType", {
        pattern = M.served_filetypes,
        callback = function(args)
            local ft = vim.bo[args.buf].filetype
            -- Defer LSP initialization to after UI is ready
            vim.defer_fn(function()
                M.start_lsp_for_ft(ft)
            end, 50)
        end,
    })
end

function M.start_lsp_for_current_ft()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    M.start_lsp_for_ft(ft, bufnr)
end

function M.start_lsp_for_ft(ft, bufnr)
    local util = require("lspconfig.util")
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    ft = ft or vim.bo[bufnr].filetype
    local server = M.filetype_map[ft]

    if not server then return end

    -- Only configure server once
    if M._setup_servers[server] then
        return
    end
    M._setup_servers[server] = true

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
        opts.root_dir = util.root_pattern("compile_commands.json")
            or util.root_pattern(".git", "Make")
    end

    if server == "pyright" then
        opts.cmd = { "pyright-langserver", "--stdio" }
        opts.root_dir = util.root_pattern("pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile",
            ".git")

        -- Detect UV environment python path
        local python_path = nil
        if vim.fn.executable("uv") == 1 then
            -- Cache python path to avoid shell call on every LSP start
            if not M._uv_python_path then
                local handle = io.popen('uv run python -c "import sys; print(sys.executable)" 2>/dev/null')
                local result = handle:read("*a"):gsub("%s+", "")
                handle:close()
                if result ~= "" and vim.fn.filereadable(result) == 1 then
                    M._uv_python_path = result
                end
            end
            python_path = M._uv_python_path
        end

        -- Fallback to system python
        if not python_path then
            python_path = vim.fn.exepath("python3") or vim.fn.exepath("python")
        end

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
    end

    vim.lsp.config(server, opts)

    -- vim.lsp.enable() only affects future buffers, so manually start for current buffer
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local root_dir = opts.root_dir and opts.root_dir(bufname) or vim.fs.dirname(bufname)

    if opts.cmd == nil then
        vim.lsp.enable(server, true)
    else
        vim.lsp.start({
            name = server,
            cmd = opts.cmd,
            root_dir = root_dir,
            capabilities = opts.capabilities,
            on_attach = function(client, buf)
                if opts.on_attach then
                    opts.on_attach(client, buf)
                end
            end,
            handlers = opts.handlers,
            settings = opts.settings,
        }, { bufnr = bufnr })
    end
end

return M
