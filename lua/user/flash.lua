local M = {
    "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
        { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
        { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
        { "r",     mode = { "o"},            function() require("flash").remote() end,            desc = "Remote Flash" },
        { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
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
