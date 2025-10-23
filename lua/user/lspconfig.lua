local icons = require('user.lspicons')

local luals_opts = {
    -- mason = false,
    -- keys = {},
    settings = {
        Lua = {
            workspace = {
                checkThirdParty = false,
            },
            completion = {
                callSnippet = "Replace",
            },
            doc = {
                privateName = { "^_" },
            },
        },
    },
}

local clangd_opts = {
    cmd = {
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
    },
    filetypes = { "c", "cpp" },
    root_markers = { "compile_commands.json", ".git", "Makefile", "Make" },
}

local function find_uv_python_path(bufnr, client, callback)
    local uv_path = vim.fn.exepath("uv")
    if uv_path == "" then
        callback(false, nil)
        return
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then
        callback(false, nil)
        return
    end

    -- read first 10 lines, looking for: /// script
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false)
    local is_uv_script = false
    for _, line in ipairs(lines) do
        if line:match("^#[%s]*///[%s]*script") then
            is_uv_script = true
            break
        end
    end

    local dir = vim.fn.fnamemodify(filepath, ":h")
    local has_fidget, progress = pcall(require, "fidget.progress")
    local handle
    if has_fidget then
        handle = progress.handle.create({
            title = "UV Python",
            message = "Checking configuration...",
            lsp_client = client and { name = client.name } or nil,
        })
    end

    local function report_progress(message, percentage)
        if handle then
            handle:report({
                message = message,
                percentage = percentage,
            })
        end
    end
    local function end_progress(message)
        if handle then
            handle:finish(message)
        end
    end
    report_progress("Checking UV configuration...", 0)

    local function check_script_python()
        if not is_uv_script then
            Find_project_python()
            return
        end
        report_progress("Detecting UV script environment...", 20)
        vim.system(
            { "uv", "python", "find", "--script", filepath },
            { text = true, timeout = 1000 },
            vim.schedule_wrap(function(script_result)
                Find_project_python(script_result)
            end)
        )
    end

    function Find_project_python(script_result)
        report_progress("Finding Python interpreter...", 40)
        vim.system(
            { "uv", "python", "find" },
            { text = true, timeout = 1000, cwd = dir },
            vim.schedule_wrap(function(project_result)
                if is_uv_script then
                    if script_result and script_result.stdout == project_result.stdout then
                        Create_script_env()
                    else
                        Finalize_result(script_result)
                    end
                else
                    Finalize_result(project_result)
                end
            end)
        )
    end

    function Create_script_env()
        report_progress("Creating UV script environment...", 60)
        vim.system(
            { "uv", "run", "--script", filepath, "--", "--version" },
            { text = true, timeout = 5000 },
            vim.schedule_wrap(function(_)
                report_progress("Finalizing script environment...", 80)
                vim.system(
                    { "uv", "python", "find", "--script", filepath },
                    { text = true, timeout = 1000 },
                    vim.schedule_wrap(function(final_result)
                        Finalize_result(final_result)
                    end)
                )
            end)
        )
    end

    function Finalize_result(result)
        if not result or not result.stdout then
            end_progress("UV detection failed")
            callback(is_uv_script, nil)
            return
        end

        local python_path = result.stdout:match("^%s*(.-)%s*$")
        if python_path ~= "" and vim.fn.executable(python_path) == 1 then
            if is_uv_script and python_path:match(vim.fn.fnamemodify(filepath, ":t:r")) == nil then
                end_progress("Using global Python paths")
            elseif is_uv_script then
                end_progress("UV script environment configured")
            else
                end_progress("UV project environment configured")
            end
            callback(is_uv_script, python_path)
        else
            end_progress("No valid Python interpreter found")
            callback(is_uv_script, nil)
        end
    end

    check_script_python()
end

local default_python = vim.fn.exepath("python3") or vim.fn.exepath("python")
local pyright_opts = {
    cmd = { "pyright-langserver", "--stdio" },
    settings = {
        python = {
            pythonPath = default_python,
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
            }
        }
    },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", ".git" },
    on_attach = function(client, bufnr)
        find_uv_python_path(bufnr, client, function(_, uv_python)
            if not uv_python then
                return
            end
            vim.lsp.config.pyright = {
                settings = {
                    python = {
                        pythonPath = uv_python,
                    }
                }
            }
            vim.lsp.enable("pyright", false)
            vim.lsp.enable("pyright", true)
        end)
    end,
}

return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            "mason.nvim",
            "folke/lazydev.nvim",
            { "mason-org/mason-lspconfig.nvim", config = function() end },
        },
        opts = function()
            local ret = {
                diagnostics = {
                    underline = function(_, bufnr)
                        return #vim.diagnostic.get(bufnr) <= 10
                    end,
                    update_in_insert = false,
                    virtual_text = false,
                    severity_sort = true,
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
                    float = {
                        focusable = true,
                        border = "rounded",
                        source = "if_many",
                        header = "",
                        prefix = "",
                    },
                },
                inlay_hints = {
                    enabled = false,
                },
                codelens = {
                    enabled = true,
                },
                folds = {
                    enabled = false,
                },
                capabilities = {
                    workspace = {
                        fileOperations = {
                            didRename = true,
                            willRename = true,
                        },
                    },
                },
                format = {
                    formatting_options = nil,
                    timeout_ms = nil,
                },
                servers = {
                    stylua = { enabled = false },
                    lua_ls = luals_opts,
                    clangd = clangd_opts,
                    pyright = pyright_opts,
                },
                setup = {
                    lua_ls = function()
                        require("lazydev").setup()
                    end
                },
            }
            return ret
        end,
        config = vim.schedule_wrap(function(_, opts)
            if opts.inlay_hints.enabled then
                vim.api.nvim_create_autocmd("LspAttach", {
                    group = vim.api.nvim_create_augroup("UserLspInlayHints", {}),
                    callback = function(ev)
                        local client = vim.lsp.get_client_by_id(ev.data.client_id)
                        local buffer = ev.buf
                        if client and client.server_capabilities.inlayHintProvider then
                            if
                                vim.api.nvim_buf_is_valid(buffer)
                                and vim.bo[buffer].buftype == ""
                                and not vim.tbl_contains(opts.inlay_hints.exclude, vim.bo[buffer].filetype)
                            then
                                vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
                            end
                        end
                    end,
                })
            end

            if opts.folds.enabled then
                vim.api.nvim_create_autocmd("LspAttach", {
                    group = vim.api.nvim_create_augroup("UserLspFolds", {}),
                    callback = function(ev)
                        local client = vim.lsp.get_client_by_id(ev.data.client_id)
                        if client and client.server_capabilities.foldingRangeProvider then
                            if vim.wo.foldmethod == "manual" then
                                vim.wo.foldmethod = "expr"
                                vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
                            end
                        end
                    end,
                })
            end

            if opts.codelens.enabled and vim.lsp.codelens then
                vim.api.nvim_create_autocmd("LspAttach", {
                    group = vim.api.nvim_create_augroup("UserLspCodeLens", {}),
                    callback = function(ev)
                        local client = vim.lsp.get_client_by_id(ev.data.client_id)
                        local buffer = ev.buf
                        if client and client.server_capabilities.codeLensProvider then
                            vim.lsp.codelens.refresh()
                            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
                                buffer = buffer,
                                callback = vim.lsp.codelens.refresh,
                            })
                        end
                    end,
                })
            end

            if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
                opts.diagnostics.virtual_text.prefix = function(diagnostic)
                    for d, icon in pairs(icons.diagnostics) do
                        if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
                            return icon
                        end
                    end
                    return "●"
                end
            end
            vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

            if opts.capabilities then
                vim.lsp.config("*", { capabilities = opts.capabilities })
            end

            local have_mason = pcall(require, "mason-lspconfig")
            local mason_all = have_mason
                and vim.tbl_keys(require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package)
                or {} --[[ @as string[] ]]
            local mason_exclude = {} ---@type string[]

            local function configure(server)
                local sopts = opts.servers[server]
                sopts = sopts == true and {} or (not sopts) and { enabled = false } or sopts

                if sopts.enabled == false then
                    mason_exclude[#mason_exclude + 1] = server
                    return
                end

                local use_mason = sopts.mason ~= false and vim.tbl_contains(mason_all, server)
                local setup = opts.setup[server] or opts.setup["*"]
                if setup and setup(server, sopts) then
                    mason_exclude[#mason_exclude + 1] = server
                else
                    vim.lsp.config(server, sopts) -- configure the server
                    if not use_mason then
                        vim.lsp.enable(server)
                    end
                end
                return use_mason
            end

            local install = vim.tbl_filter(configure, vim.tbl_keys(opts.servers))
            if have_mason then
                require("mason-lspconfig").setup({
                    ensure_installed = install,
                    automatic_enable = { exclude = mason_exclude },
                })
            end
        end),
    },

    -- cmdline tools and lsp servers
    {

        "mason-org/mason.nvim",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
        build = ":MasonUpdate",
        opts_extend = { "ensure_installed" },
        opts = {
            ensure_installed = {
                "stylua",
                "shfmt",
            },
        },
        ---@param opts MasonSettings | {ensure_installed: string[]}
        config = function(_, opts)
            require("mason").setup(opts)
            local mr = require("mason-registry")
            mr:on("package:install:success", function()
                vim.defer_fn(function()
                    -- trigger FileType event to possibly load this newly installed LSP server
                    require("lazy.core.handler.event").trigger({
                        event = "FileType",
                        buf = vim.api.nvim_get_current_buf(),
                    })
                end, 100)
            end)

            mr.refresh(function()
                for _, tool in ipairs(opts.ensure_installed) do
                    local p = mr.get_package(tool)
                    if not p:is_installed() then
                        p:install()
                    end
                end
            end)
        end,
    },
}
