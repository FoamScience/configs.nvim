-- neotest — test runner UI. Generic setup only; python via neotest-python
-- (pytest). Project-specific test workflows (e.g. the centri-pump suite) live in
-- user-config.elwardi/plugins/. Keymaps under <leader>t (group in whichkey.lua).
local M = {
    "nvim-neotest/neotest",
    dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "nvim-neotest/neotest-python",
    },
    ft = { "python" },
    cmd = "Neotest",
}

M.keys = {
    { "<leader>tt", function() require("neotest").run.run() end,                            desc = "Run nearest" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end,          desc = "Run file" },
    { "<leader>td", function() require("neotest").run.run(vim.fn.getcwd()) end,             desc = "Run directory" },
    { "<leader>tl", function() require("neotest").run.run_last() end,                       desc = "Run last" },
    { "<leader>ts", function() require("neotest").summary.toggle() end,                     desc = "Toggle summary" },
    { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show output" },
    { "<leader>tO", function() require("neotest").output_panel.toggle() end,                desc = "Toggle output panel" },
    { "<leader>tS", function() require("neotest").run.stop() end,                           desc = "Stop" },
    { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end,     desc = "Watch file" },
}

function M.config()
    require("neotest").setup({
        adapters = {
            require("neotest-python")({
                runner = "pytest",
                -- neotest-python auto-detects venv/.venv in the test root, which
                -- covers the uv-managed projects here.
                -- Per-target extra pytest args (e.g. --stage-input-line for the
                -- centri-pump suite) are registered in _G.NeotestExtraArgs by
                -- user configs and matched here by path prefix.
                args = function(_, position, _)
                    local extra, path = {}, position and position.path or ""
                    for prefix, argv in pairs(_G.NeotestExtraArgs or {}) do
                        if path:sub(1, #prefix) == prefix then
                            vim.list_extend(extra, argv)
                        end
                    end
                    return extra
                end,
                dap = { justMyCode = false },
            }),
        },
        quickfix = { enabled = false }, -- nvim-bqf / trouble own the quickfix UI
        output = { open_on_run = "short" },
        status = { virtual_text = true, signs = true },
    })
end

return M
