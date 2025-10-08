local M = {
    "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
        { "gs",    mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash jump" },
        { "gS",    mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter jump" },
        { "s",     mode = { "o" },           function() require("flash").jump() end,              desc = "Flash jump" },
        { "S",     mode = { "o" },           function() require("flash").treesitter() end,        desc = "Flash Treesitter jump" },
        { "r",     mode = { "o" },           function() require("flash").remote() end,            desc = "Remote Flash jump" },
        { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search jump" },
        { "<c-s>", mode = { "c", "n" },      function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
    },
}

function M.config()
    require 'flash'.setup {
        mode = "fuzzy",
        incremental = true,
    }
end

return M
