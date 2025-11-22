local icons = require('user.lspicons')
local utils = require('utils.lsp')

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
        --"--all-scopes-completion",
        "--completion-style=bundled",
        "--clang-tidy",
        "--malloc-trim",
        "--function-arg-placeholders",
        "--header-insertion=iwyu",
        "--header-insertion-decorators",
        "--enable-config",
        "--background-index",
        "--background-index-priority=low",
        "--cross-file-rename",
        "--suggest-missing-includes",
    },
    filetypes = { "c", "cpp" },
    root_markers = { "compile_commands.json", ".git", "Makefile", "Make" },
    on_attach = function(client, bufnr)
        vim.schedule_wrap(function()
            local db_path = client.root_dir .. "/compile_commands.json"
            if not vim.loop.fs_stat(db_path) then return end
            local workspace_files = vim.fn.split(vim.fn.system("jq -r '.[].file' " .. db_path), "\n")
            utils.workspace_diagnostics(client, bufnr, workspace_files)
        end)
    end
}

local find_uv_python_path = utils.find_uv_python_path
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
            {
                "p00f/clangd_extensions.nvim",
                ft = "cpp",
                event = { "LspAttach" },
                opts = {
                    ast = {
                        role_icons = {
                            type = icons.kind.Struct,
                            declaration = icons.kind.Interface,
                            expression = icons.kind.Operator,
                            statement = icons.kind.Namespace,
                            specifier = icons.kind.Constant,
                            ["template argument"] = icons.kind.TypeParameter,
                        },
                        kind_icons = {
                            Compound = icons.kind.Constructor,
                            Recovery = icons.misc.CircuitBoard,
                            TranslationUnit = icons.misc.Package,
                            PackExpansion = icons.ui.Ellipsis,
                            TemplateTypeParm = icons.kind.TypeParameter,
                            TemplateTemplateParm = icons.kind.Variable,
                            TemplateParamObject = icons.kind.Object,
                        },
                    },
                    memory_usage = {
                        border = "single",
                    },
                    symbol_info = {
                        border = "single",
                    },
                }
            }
        },
        opts = function()
            local ret = {
                diagnostics = {
                    underline = function(_, bufnr)
                        return #vim.diagnostic.get(bufnr) <= 5
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
                        require("lazydev").setup({
                            ft = "lua",
                        })
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
        keys = { { "<leader>lm", "<cmd>Mason<cr>", desc = "Mason" } },
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
