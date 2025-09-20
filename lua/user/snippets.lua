local M = {
    "L3MON4D3/LuaSnip",
    build = "make install_jsregexp",
    event = "VeryLazy",
    dependencies = {
        "rafamadriz/friendly-snippets",
    },
}

M.config = function()
    require("luasnip").setup{}
end

return M
