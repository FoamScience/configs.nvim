local icons = require('user.lspicons')

-- Define server options as functions to be evaluated when lspconfig is available
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

-- Function to find Python path using UV
local function find_uv_python_path(bufnr)
    local uv_path = vim.fn.exepath("uv")
    if uv_path == "" then return nil end
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then return nil end

    -- if no file yet, no point in continuing

    -- read first 10 lines, looking for: /// script
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false)
    local is_uv_script = false
    for _, line in ipairs(lines) do
        if line:match("^#[%s]*///[%s]*script") then
            is_uv_script = true
            break
        end
    end
    local script_result
    local success_script
    if is_uv_script then
        script_result = vim.system(
            { "uv", "python", "find", "--script", filepath },
            { text = true, timeout = 1000 }
        ):wait()
    end
    local dir = vim.fn.fnamemodify(filepath, ":h")
    local cmd = string.format("cd %s && uv python find", vim.fn.shellescape(dir))

    local result = vim.system(
        { "uv", "python", "find" },
        { text = true, timeout = 1000, cwd = dir }
    ):wait()

    vim.print("IS_SCRIPT but NOT DETECTED?")
    vim.print(result, script_result)
    vim.print(is_uv_script and script_result.stdout == result.stdout)
    if is_uv_script and script_result.stdout == result.stdout then
        -- force creation of environment, sneaky workaround
        vim.system(
            { "uv", "run", "--script", filepath, "--", "--version" },
            { text = true, timeout = 5000 }
        ):wait()
        result = vim.system(
            { "uv", "python", "find", "--script", filepath },
            { text = true, timeout = 1000 }
        ):wait()
    end

    local python_path = result.stdout:match("^%s*(.-)%s*$")
    if python_path ~= "" and vim.fn.executable(python_path) == 1 then
        return is_uv_script, python_path
    end

    return is_uv_script, nil
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
    on_attach = function(_, bufnr)
        local is_script, uv_python = find_uv_python_path(bufnr)
        if is_script and uv_python then
            vim.print("UV script detected, setting environment")
        end
        if not is_script and uv_python then
            vim.print("UV project detected, setting environment")
        end
        if uv_python then
            vim.lsp.config.pyright = {
                settings = {
                    python = {
                        pythonPath = uv_python,
                    }
                }
            }
            vim.lsp.enable("pyright", false)
            vim.lsp.enable("pyright", true)
        end
    end,
}

return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            "mason.nvim",
            { "mason-org/mason-lspconfig.nvim", config = function() end },
        },
        opts = function()
            local ret = {
                diagnostics = {
                    underline = function(_, bufnr)
                        return #vim.diagnostic.get(bufnr) <= 10
                    end,
                    update_in_insert = false,
                    virtual_text = {
                        spacing = 4,
                        source = "if_many",
                        prefix = "●",
                    },
                    severity_sort = true,
                    signs = {
                        text = {
                            [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
                            [vim.diagnostic.severity.WARN] = icons.diagnostics.Warning,
                            [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
                            [vim.diagnostic.severity.INFO] = icons.diagnostics.Information,
                        },
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
                setup = {},
            }
            return ret
        end,
        config = vim.schedule_wrap(function(_, opts)
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspConfig", {}),
                callback = function(ev)
                    --on_attach(vim.lsp.get_client_by_id(ev.data.client_id), ev.buf)
                end,
            })

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
                sopts = sopts == true and {} or (not sopts) and { enabled = false } or sopts --[[@as lsp.Config]]

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
