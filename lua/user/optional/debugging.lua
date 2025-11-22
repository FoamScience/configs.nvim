local M = {
    "igorlfs/nvim-dap-view",
    dependencies = { { "mfussenegger/nvim-dap" } },
    event = "LspAttach",
}

M.config = function()
    local dap = require('dap')
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients >= 1 and vim.bo.ft == "python" then
        dap.configurations.python = {
            {
                type = 'python',
                request = 'launch',
                name = "Python environment from LSP client",
                program = "${file}",
                pythonPath = function()
                    return vim.lsp.get_clients({ bufnr = 0 })[1].config.settings.python.pythonPath
                end,
            },
        }
        dap.adapters.python = function(cb, config)
            if config.request == 'attach' then
                local port = (config.connect or config).port
                local host = (config.connect or config).host or '127.0.0.1'
                cb({
                    type = 'server',
                    port = assert(port, '`connect.port` is required for a python `attach` configuration'),
                    host = host,
                    options = {
                        source_filetype = 'python',
                    },
                })
            else
                cb({
                    type = 'executable',
                    command = vim.lsp.get_clients({ bufnr = 0 })[1].config.settings.python.pythonPath,
                    args = { '-m', 'debugpy.adapter' },
                    options = {
                        source_filetype = 'python',
                    },
                })
            end
        end
    end
    if #clients >= 1 and vim.tbl_contains({ "c", "c++", "rust" }, vim.bo.ft) then
        dap.adapters.gdb = {
            type = "executable",
            command = "gdb",
            args = { "--interpreter=dap", "--eval-command", "set print pretty on" }
        }
        dap.configurations.c = {
            {
                name = "Launch",
                type = "gdb",
                request = "launch",
                program = function()
                    return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                end,
                args = {},
                cwd = "${workspaceFolder}",
                stopAtBeginningOfMainSubprogram = false,
            },
            {
                name = "Select and attach to process",
                type = "gdb",
                request = "attach",
                program = function()
                    return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                end,
                pid = function()
                    local name = vim.fn.input('Executable name (filter): ')
                    return require("dap.utils").pick_process({ filter = name })
                end,
                cwd = '${workspaceFolder}'
            },
            {
                name = 'Attach to gdbserver :1234',
                type = 'gdb',
                request = 'attach',
                target = 'localhost:1234',
                program = function()
                    return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                end,
                cwd = '${workspaceFolder}'
            }
        }
        dap.configurations.cpp = dap.configurations.c
        dap.configurations.rust = dap.configurations.c
    end
    local keymap_restore = {}
    dap.listeners.after['event_initialized']['me'] = function()
        for _, buf in pairs(vim.api.nvim_list_bufs()) do
            local keymaps = vim.api.nvim_buf_get_keymap(buf, 'n')
            for _, keymap in pairs(keymaps) do
                if keymap.lhs == "K" then
                    table.insert(keymap_restore, keymap)
                    vim.api.nvim_buf_del_keymap(buf, 'n', 'K')
                end
            end
        end
        vim.api.nvim_set_keymap(
            'n', 'K', '<Cmd>lua require("dap.ui.widgets").hover()<CR>', { silent = true })
    end
    dap.listeners.after['event_terminated']['me'] = function()
        for _, keymap in pairs(keymap_restore) do
            if keymap.rhs then
                vim.api.nvim_buf_set_keymap(
                    keymap.buffer,
                    keymap.mode,
                    keymap.lhs,
                    keymap.rhs,
                    { silent = keymap.silent == 1 }
                )
            elseif keymap.callback then
                vim.keymap.set(
                    keymap.mode,
                    keymap.lhs,
                    keymap.callback,
                    { buffer = keymap.buffer, silent = keymap.silent == 1 }
                )
            end
        end
        keymap_restore = {}
    end
    require('dap-view').setup({
        winbar = {
            sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl", "sessions", "console" },
            base_sections = {
                breakpoints = {
                    label = "Breakpoints  [B]",
                },
                scopes = {
                    label = "Scopes 󰂥 [S]",
                },
                exceptions = {
                    label = "Exceptions 󰢃 [E]",
                },
                watches = {
                    label = "Watches 󰛐 [W]",
                },
                threads = {
                    label = "Threads 󱉯 [T]",
                },
                repl = {
                    label = "REPL 󰯃 [R]",
                },
                sessions = {
                    label = "Sessions  [K]",
                },
                console = {
                    label = "Console 󰆍 [C]",
                },
            },
            controls = {
                enabled = false,
            }
        },
        windows = {
            height = 0.4,
        },
        icons = {
            disabled = " ",
            disconnect = " ",
            enabled = " ",
            filter = "󰈲 ",
            negate = " ",
            pause = " ",
            play = " ",
            run_last = " ",
            step_back = " ",
            step_into = " ",
            step_out = " ",
            step_over = " ",
            terminate = " ",
        },
    })

    vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DiagnosticError' })
    vim.fn.sign_define('DapStopped', { text = '', texthl = 'DiagnosticWarn', linehl = 'CursorLine' })
    vim.fn.sign_define('DapBreakpointRejected', { text = '', texthl = 'DiagnosticHint' })
    vim.fn.sign_define('DapLogPoint', { text = '', texthl = 'DiagnosticInfo' })
    vim.fn.sign_define('DapBreakpointCondition', { text = '', texthl = 'DiagnosticInfo' })
end

return M
