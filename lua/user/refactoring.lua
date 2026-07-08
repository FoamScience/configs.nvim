-- refactoring.nvim — language-aware extract/inline (C++, Python, Lua, ...).
-- select_refactor() routes through vim.ui.select → snacks. Keymaps under
-- <leader>r (group in whichkey.lua).
return {
    "ThePrimeagen/refactoring.nvim",
    -- 0.12 rewrite: only dep is async.nvim (dropped plenary; TS queries ship with
    -- the plugin). setup() is optional but harmless.
    dependencies = { "lewis6991/async.nvim" },
    keys = {
        { "<leader>re", function() require("refactoring").refactor("Extract Function") end,         mode = "x",          desc = "Extract function" },
        { "<leader>rf", function() require("refactoring").refactor("Extract Function To File") end, mode = "x",          desc = "Extract function to file" },
        { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end,         mode = "x",          desc = "Extract variable" },
        { "<leader>ri", function() require("refactoring").refactor("Inline Variable") end,          mode = { "n", "x" }, desc = "Inline variable" },
        { "<leader>rb", function() require("refactoring").refactor("Extract Block") end,            mode = "n",          desc = "Extract block" },
        { "<leader>rr", function() require("refactoring").select_refactor() end,                    mode = { "n", "x" }, desc = "Select refactor" },
    },
    opts = {},
}
