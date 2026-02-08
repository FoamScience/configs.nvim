local M = {
    "L3MON4D3/LuaSnip",
    build = "make install_jsregexp",
    event = "VeryLazy",
    lazy = true,
    dependencies = {
        "rafamadriz/friendly-snippets",
    },
}

M.config = function()
    local ls = require("luasnip")
    ls.setup{}

    -- Tab/S-Tab to jump between snippet nodes (not Enter)
    vim.keymap.set({ "i", "s" }, "<Tab>", function()
        if ls.expand_or_jumpable() then
            ls.expand_or_jump()
        else
            -- Fall back to normal tab
            return "<Tab>"
        end
    end, { silent = true, expr = true })

    vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
        if ls.jumpable(-1) then
            ls.jump(-1)
        else
            return "<S-Tab>"
        end
    end, { silent = true, expr = true })
end

return M
